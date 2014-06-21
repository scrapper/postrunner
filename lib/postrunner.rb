$:.unshift(File.join(File.dirname(__FILE__), '..', '..', 'fit4ruby', 'lib'))
$:.unshift(File.dirname(__FILE__))

require 'postrunner/version'
require 'postrunner/Main'

module PostRunner

  Main.new(ARGV)

end
