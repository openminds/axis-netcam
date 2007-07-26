= AxisNetcam

<i>Copyright 2007 Urbacon Ltd.</i>

For info and downloads please see:

  http://rubyforge.org/projects/axis-netcam/

You can contact the author at:

  matt at roughest dot net
  

<b>AxisNetcam provides a Ruby interface for interacting with network cameras
from  Axis Communications.</b>

Note that only a subset of the full Axis API is currently implemented, but the most
useful functionality is in place.

To install (using RubyGems[http://rubygems.org/read/chapter/3]):

  gem install axis-netcam

Example usage:

  require 'rubygems' # (if installed as a gem)
  require 'axis-netcam'
  
  c = AxisNetcam::Camera.new(:hostname => '192.168.2.25', 
        :username => 'root', :password => 'pass')
  c.tilt(90)
  c.zoom(500)
  f = File.open('/tmp/test.jpg', 'wb')
  f.bin
  f.write(c.snapshot_jpeg)
  f.close
  
For more information about using a Camera object, see the AxisNetcam::Camera RDocs.


------

axis-netcam is free software; you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

axis-netcam is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.