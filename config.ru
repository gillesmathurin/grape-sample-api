require File.expand_path File.join(File.dirname(__FILE__), 'app')

use Rack::Deflater
run EpttAPI