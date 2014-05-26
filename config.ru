require 'rack/cors'
require File.expand_path('../config/environment.rb', __FILE__)

use Rack::Deflater
use Rack::Cors do
  allow do
    origins '*'
  end
end
run EpttAPI
