module AxisNetcam
end

Dir[File.join(File.dirname(__FILE__), 'axis-netcam/**/*.rb')].sort.each { |lib| require lib }