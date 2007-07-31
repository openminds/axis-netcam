#--
# This file is part of axis-netcam.
#
# By Matt Zukowski <matt at roughest dot net>.
# Copyright (2007) Urbacon Ltd.
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
    @@http = nil
    
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
        str = axis_action("com/ptz.cgi", {'query' => 'position'}).split
        pan = str[0].split("=").last
        tilt = str[1].split("=").last
        zoom = str[2].split("=").last
        
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
      
      def point_at_preset_name(preset_name)
        axis_action("com/ptz.cgi", {'gotoserverpresetname' => preset_name})
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
    end
    include Video
    
    # Functionality related to obtaining information about the camera, such as its
    # status, model number, etc.
    module Info
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
        begin
          server_report =~ /prodshortname\s*=\s*"(.*?)"/i
          $~[1]
        rescue RemoteTimeout, RemoteError => e
          @error = e
          nil
        end
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
            
    #        if @@http && @@http.active?
    #          @log.debug "AXIS REMOTE API reusing HTTP connection #{@@http}"
    #          http = @@http
    #        else
              @log.debug "AXIS REMOTE API opening new HTTP connection to '#{hostname}'"
              http = Net::HTTP.start(hostname)
              http.read_timeout = 15 # wait 15 seconds for camera to respond, then give up
              http.open_timeout = 15
    #          @@http = http
    #        end
            
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
