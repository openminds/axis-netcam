#--
# This file is part of axis-netcam.
#
# Copyright (2007) Matt Zukowski <matt at roughest dot net>.
# 
# axis-netcam is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# axis-netcam is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#--

require 'net/http'
require 'cgi'
require 'logger'

module AxisNetcam
  # The AxisNetcam::Camera class represents an Axis network camera.
  #
  # To control a camera, first create an instance of a Camera object and then call
  # its methods. For example:
  #
  #   require 'axis-netcam/camera'
  #
  #   c = AxisNetcam::Camera.new(:hostname => '192.168.2.25', 
  #         :username => 'root', :password => 'pass')
  #
  #   puts c.get_position[:tilt]
  #   c.tilt(90)
  #   puts c.camera_video_uri
  #
  # For a list of available methods, see the RDocs for included modules:
  # AxisNetcam::Camera::PTZ :: for point-tilt-zoom control
  # AxisNetcam::Camera::Users :: for user management
  # AxisNetcam::Camera::Video :: for obtaining video/image data
  # AxisNetcam::Camera::Info :: for diagnostic/status information
  #
  # Note that by default, AxisNetcam::Camera will log quite verbosely to stdout.
  # See AxisNetcam::Camera#new for info on how to change this behaviour.
  class Camera
    
    # The HTTP network connection to the camera.
    @http = nil
    
    attr_reader :hostname, :logger
    
    # Create a new Camera object.
    # Options must include a :hostname, :username, and :password.
    # A Logger object can also be specified to the :logger option, otherwise 
    # logging will be done to STDOUT.
    def initialize(options)
      @hostname = options[:hostname] or raise(ArgumentError, "Must specify a hostname")
      @username = options[:username] or raise(ArgumentError, "Must specify a username")
      @password = options[:password] or raise(ArgumentError, "Must specify a password")
      @log = options[:logger] || Logger.new(STDOUT)
    end
    
    
    # Functionality related to the camera's point, zoom, and tilt.
    # Not all camera models support this.
    module PTZ
      
      # Returns the camera's current absolute position as a hash with :pan, 
      # :tilt, and :zoom elements.
      #
      # :tilt and :pan are specified in degrees from center (for example, -170 
      # to 170 for :pan, depending on your camera's physical capabilities), and
      # zoom is an integer factor, with 0 being no zoom (widest possible
      # viewing angle) and 10000 approaching a camera's maximum zoom. Again,
      # this depends on your camera's capabilities.
      def get_position
        raw = axis_action("com/ptz.cgi", {'query' => 'position'})
        str = raw.split
        pan = str[0].split("=").last.to_f
        tilt = str[1].split("=").last.to_f
        zoom = str[2].split("=").last.to_i
        
        {:pan => pan, :tilt => tilt, :zoom => zoom}
      end
      
      # Simultanously pans, tilts, and zooms the camera.
      # The argument is a hash that can have any of 'pan', 'tilt', and 'zoom' 
      # elements, each specifying the desired value for the movement.
      #
      # Example:
      #  
      #   camera.ptz(:pan => 60, :zoom => 8000)
      #
      def ptz(ptz = {})
        axis_action('com/ptz.cgi', ptz)
      end
      
      # Tilts the camera (up/down) to the given absolute position in degrees.
      def tilt(d)
        axis_action("com/ptz.cgi", {'tilt'  => d})
      end
      
      # Pans the camera (left/right) to the given absolute position in degrees.
      def pan(d)
        axis_action("com/ptz.cgi", {'pan'  => d})
      end
      
      # Zooms the camera (in/out) to the given zoom factor.
      def zoom(n)
        axis_action("com/ptz.cgi", {'zoom'  => n})
      end
    
      # Zooms the camera (in/out) to the given zoom factor.
      def center_on(x,y)
        axis_action("com/ptz.cgi", {'center'  => "#{x},#{y}"})
      end
      
      # Returns and array with the names of the preset positions saved in the camera.
      def get_preset_positions
        str = axis_action("com/ptz.cgi", {'query' => 'presetposall'})
        positions = []
        str.each do |line|
          line =~ /presetposno\d+=(.*)/
          positions << $~[1].strip if $~ && $~[1]
        end
        positions
      end
      
      # Returns a hash with info about the camera's point-tilt-zoom limits.
      #
      # The returned hash will look something like:
      #
      #   {'MinPan' => "-169",
      #    'MaxPan' => "169",
      #    'MinTilt' => "-90",
      #    'MaxTilt' => "10",
      #    'MinZoom' => "1",
      #    'MaxZoom' => "19999"}
      #
      # The pan and tilt limit values assume that your camera's image is not
      # rotated. If you want to use these values in <tt>ptz</tt> calls
      # and your image is configured to be rotated, then you should also
      # specify <tt>:imagerotation => 0</tt> as one of your parameters
      # to <tt>ptz</tt>. For example:
      #
      #   limits = c.get_ptz_limits
      #   c.ptz(:tilt => limits['MaxTilt'], :imagerotation => 0)
      #
      # Alternatively, you can specify a +rotation+ argument. This will
      # automatically adjust the returned pan and tilt values to match
      # the given rotation. You can also specify :auto instead of providing
      # a numeric value, in which case the system will try to fetch
      # the rotation value for you (but be careful, because this can slow
      # things down, since the camera must be queried first).
      def get_ptz_limits(rotation = nil)
        l = get_parameters("PTZ.Limit.L1")
        return l unless rotation
        
        rotation = get_current_image_rotation if rotation == :auto
        
        # TODO: this only works for the 0, 90, 180, 270 rotations but not arbitrary values
        case rotation
        when 90
          l['MinPan'], l['MaxPan'], l['MinTilt'], l['MaxTilt'] =
          l['MinTilt'], l['MaxTilt'], l['MinPan'], l['MaxPan']
        when 180
          l['MinPan'], l['MaxPan'], l['MinTilt'], l['MaxTilt'] =
          l['MinPan'], l['MaxPan'], l['MaxTilt']*-1, l['MinTilt']*-1
        when 270
          l['MinPan'], l['MaxPan'], l['MinTilt'], l['MaxTilt'] =
          l['MinTilt'], l['MaxTilt'], l['MinPan']*-1, l['MaxPan']*-1
        end
        
        l
      end
      
      # Points the camera at the given preset.
      def point_at_preset_name(preset_name)
        axis_action("com/ptz.cgi", {'gotoserverpresetname' => preset_name})
      end
      
      # Tries to 'calibrate' the camera by rotating to all extremes.
      #
      # This may be useful when the camera is shifted by some external
      # force and looses its place. Running the calibration should reset 
      # things so that the camera's absolute point and tilt co-ordinates are
      # consistent relative to the camera's base.
      def calibrate
        @log.info("Starting camera calibration...")
        
        pos = get_position
        limits = get_ptz_limits(:auto)
        
        zoom(limits['MinZoom'])
        sleep(5)
        ptz(:pan => limits['MinPan'], :tilt => limits['MinTilt'])
        sleep(5)
        ptz(:pan => limits['MinPan'], :tilt => limits['MaxTilt'])
        sleep(5)
        ptz(:pan => limits['MaxPan'], :tilt => limits['MaxTilt'])
        sleep(5)
        ptz(:pan => limits['MaxPan'], :tilt => limits['MinTilt'])
        sleep(5)
        
        ptz(pos)
        
        @log.info("Finished camera calibration.")
      end
    end
    include PTZ
    
    # Functionality related to managing the camera's user and group lists.
    module Users
    
      # Adds a new user based on the given hash.
      # The hash must have :username, :password, and :comment elements.
      def add_user(user)
        params = {
          'action'  => 'add',
          'user'    => user[:username],
          'pwd'     => user[:password],
          'comment' => user[:comment],
          'grp'     => 'users',
          'sgrp'    => 'axview'
        }
        axis_action("admin/pwdgrp.cgi", params)
      end
      
      # Updates a user based on the given hash.
      # username :: specifies the username of the user to update.
      # attributes :: must be a hash with new values for :password and :comment.
      def update_user(username, attributes)
        params = {
          'action'  => 'update',
          'user'    => username,
          'pwd'     => user[:password],
          'comment' => user[:comment],
          'grp'     => 'users',
          'sgrp'    => 'axview'
        }
        axis_action("admin/pwdgrp.cgi", params)
      end
      
      # Same as add_user, but updates the user account instead of creating it
      # if it already exists.
      def add_or_update_user(user)
        if user_exists?(user[:username], user)
          update_user(user[:username], user)
        else
          add_user(user)
        end
      end
      
      # Deletes the user with the given username.
      def remove_user(username)
        params = {
          'action'  => 'remove',
          'user'    => username,
        }
        axis_action("admin/pwdgrp.cgi", params)
      end
      
      # Returns an array with the usernames of the users on the camera.
      def users
        str = axis_action("admin/pwdgrp.cgi", {'action' => 'get'})
        return false unless str
        usernames = []
        str.split.collect do |u| 
          u =~ /.*?="(.*)"/
          if $~
            usernames += $~[1].split(',')
          else
            usernames += []
          end
        end
        usernames.uniq!
      end
      
      # Checks if the user with the given username exists.
      def user_exists?(username)
        users.include? username
      end
    end
    include Users
    
    
    # Functionality related to the camera's video/image capabilities.
    module Video
      # Returns JPEG data with a snapshot of the current camera image.
      # size :: optionally specifies the image size -- one of :full, :medium, 
      #         or :thumbnail, or a string specifying the WxH dimensions like "640x480".
      #
      # To dump the JPEG data to a file, you can do something like this:
      #
      #   # Instantiate c as a AxisNetcam::Camera object, and then...
      #   data = c.snapshot_jpeg
      #   f = File.open('/tmp/test.jpg', 'wb')
      #   f.binmode
      #   f.write(data)
      #   f.close
      #
      def snapshot_jpeg(size = :full)
        case size
        when :thumbnail
          resolution = "160x120"
        when :medium
          resolution = "480x360"
        when :full
          resolution = "640x480"
        else
          resolution = size
        end
        
        axis_action("jpg/image.cgi", 
          {'resolution' => resolution, 'text' => '0'})
      end
      
      # Returns the URI for accessing the camera's streaming Motion JPEG video.
      # size :: optionally specifies the image size -- one of :full, :medium, 
      #         or :thumbnail, or a string specifying the WxH dimensions like "640x480".
      def camera_video_uri(size = :full)
        case size
        when :thumbnail
          resolution = "160x120"
        when :medium
          resolution = "480x360"
        when :full
          resolution = "640x480"
        end
        "http://#{hostname}/axis-cgi/mjpg/video.cgi?resolution=#{resolution}&text=0"
      end
      
      # Returns the current image rotation setting.
      def get_current_image_rotation
        v = get_parameters("Image.I0.Appearance.Rotation")
        if v && v["Image.I0.Appearance.Rotation"]
          v["Image.I0.Appearance.Rotation"]
        else
          nil
        end
      end
    end
    include Video
    
    # Functionality related to obtaining information about the camera, such as its
    # status, model number, etc.
    module Info
      # Returns a hash enumerating the camera's various parameters.
      # The +group+ parameter limits the returned values to the given group.
      # Note that if given, the group is removed from the parameter names.
      #
      # For example:
      # 
      #   c.get_parameters("PTZ.Limit")
      #
      # Returns:
      #   
      #  {"L1.MaxFocus"=>9999, "L1.MaxFieldAngle"=>50, "L1.MaxTilt"=>10, 
      #   "L1.MinFieldAngle"=>1, "L1.MaxPan"=>169, "L1.MaxIris"=>9999, 
      #   "L1.MaxZoom"=>19999, "L1.MinFocus"=>1, "L1.MinPan"=>-169, 
      #   "L1.MinIris"=>1, "L1.MinZoom"=>1, "L1.MinTilt"=>-90}
      #
      # But the following:
      #
      #   c.get_parameters("PTZ.Limit.L1")
      #
      # Returns:
      #
      #   {"MaxIris"=>9999, "MaxZoom"=>19999, "MaxTilt"=>10, "MaxFocus"=>9999,
      #    "MaxPan"=>169, "MinFieldAngle"=>1, "MinTilt"=>-90, "MinPan"=>-169, 
      #    "MinIris"=>1, "MinZoom"=>1, "MinFocus"=>1, "MaxFieldAngle"=>50}
      #
      def get_parameters(group = nil)
        params = {
          'action' => 'list', 
          'responseformat' => 'rfc'
        }
        params['group'] = group if group
        
        response = axis_action("admin/param.cgi", params)
        
        if response =~ /Error -1 getting param in group '.*?'!/
          raise RemoteError, "There is no parameter group '#{group}' on this camera."
        end
        
        values = {}
        response.each do |line|
          k,v = line.split("=")
          k.strip!
          
          if v.nil?
            v = nil
          else
            case v.strip
            when /^true$/
              v = true
            when /^false$/
              v = false
            when /^[-]?[0-9]+$/
              v = v.to_i
            when /^[-]?[0-9]+\.?[0-9]+$/
              v = v.to_f
            else
              v = v.strip
            end
          end
        
          key = k.gsub(group ? "root.#{group}." : "root.", "")
          
          values[key] = v
        end
        
        values
      end
      
      
      # Returns the raw camera server report. 
      #
      # The report is a string with info about the camera's status and parameters,
      # and differs considerably from model to model.
      #
      # If you have the Easycache Rails plugin installed, report data will be
      # cached unless the force_refresh argument is true. This is done to help
      # improve performance, as the server_report method is often called by other
      # methods to retrieve various camera info.
      def server_report(force_refresh = false)
        if Object.const_defined? "Easycache"
          if force_refresh
            Easycache.write("#{hostname}_server_report",
              @report = axis_action("admin/serverreport.cgi"))
          else
            @report ||= Easycache.cache("#{hostname}_server_report") do
              axis_action("admin/serverreport.cgi")
            end
          end
        else
          axis_action("admin/serverreport.cgi")
        end
      end
      
      # Returns the camera's model name.
      def model
        extract_value_pairs_from_server_report(['prodshortname'])['prodshortname']
      end
      
      # Returns a code describing the camera's current status.
      # The codes are as follows:
      #
      # :ok :: Camera is responding as expected.
      # :down :: Camera is not responding at all (connection is timing out).
      # :error :: Camera responded with an error.
      # :no_server_report :: Camera responded but for some reason did not return a server report.
      #
      # Calling this method updates the @status_message attribute with some more
      # detailed information about the camera's status (for example, the full error message in
      # case of an error).
      def status_code
        begin
          if self.server_report(true).empty?
            @status_message = "Server did not send report"
            :no_server_report
          else
            @status_message = "OK"
            :ok
          end
        rescue InvalidLogin => e
          @status_message = "Invalid login"
          :invalid_login
        rescue RemoteTimeout => e
          @status_message = "Timeout"
          :down
        rescue RemoteError => e
          @status_message = "Error: #{e}"
          :error
        end
      end
      alias status status_code
      
      # Returns the result of the status message resulting from the last 
      # status_code call. If no status message is available, status_code
      # will be automatically called first.
      def status_message
        if @status_message
          @status_message
        else
          status_code
          @status_message
        end
      end
    end
    include Info
    
    private
      # Executes an AXIS HTTP API call.
      # script :: the remote cgi script to call
      # params :: hash parameters to send to the script -- they will be URL-encoded for you
      def axis_action(script, params = nil)
        query = params.collect{|k,v| "#{k}=#{CGI.escape v.to_s}"}.join("&") if 
          params
        body = false
        cmd_uri = "/axis-cgi/#{script}?#{query}"
        begin
          # read/open timeouts don't seem to be working, so we gotta do it ourselves
          Timeout.timeout(15) do
            req = Net::HTTP::Get.new(cmd_uri)
            
            if @http && @http.active?
              @log.debug "AXIS REMOTE API reusing HTTP connection #{@http}"
              http = @http
            else
              @log.debug "AXIS REMOTE API opening new HTTP connection to '#{hostname}'"
              http = Net::HTTP.start(hostname)
              http.read_timeout = 15 # wait 15 seconds for camera to respond, then give up
              http.open_timeout = 15
              @http = http
            end
            
            req.basic_auth @username, @password
            
            @log.info "AXIS REMOTE API CALL [#{hostname}]: #{cmd_uri}"
            res = http.request(req)
            @log.debug "AXIS REMOTE API CALL FINISHED"
            
    #        http.finish
            
            body = res.body
            
            if res.kind_of?(Net::HTTPClientError) || res.kind_of?(Net::HTTPServerError)
              if res.kind_of?(Net::HTTPUnauthorized)
                @log.error err = "AXIS CAMERA INVALID LOGIN [#{hostname}] for username '#{@username}'"
                raise InvalidLogin, "Invalid login for username '#{@username}'"
              else
                @log.error err = "AXIS CAMERA ERROR [#{hostname}]: #{cmd_uri} -- #{body}"
                raise RemoteError, body
              end          
            end
          end
          if body =~ /Error: (.*?)<\/body>/
            @log.error err = "AXIS CAMERA ERROR [#{hostname}]: #{cmd_uri} -- #{$~[1]}"
            raise RemoteError, err
          else
            body
          end
        rescue Timeout::Error
          @log.error err = "AXIS CAMERA #{hostname} TIMED OUT!"
          raise RemoteTimeout, err
        end
      end
      
      def extract_value_pairs_from_server_report(keys)
        values = {}
        report = server_report
        begin
          keys.each do |k|
            report =~ Regexp.new(%{#{k}\s*=\s*"(.*?)"}, "i")
            values[k] = $~[1] if $~ && $~[1]
          end
        rescue RemoteTimeout, RemoteError => e
          @error = e
          nil
        end
        
        values
      end
    
      # Raised when a Camera is instantiated with incorrect username and/or password.
      class InvalidLogin < Exception
      end
      # Raised when the camera responds with some error.
      class RemoteError < Exception
      end
      # Raised when the remote camera does not respond within the timeout period.
      class RemoteTimeout < Exception
      end
  end
end
