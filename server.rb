require "rubygems"
require "bundler/setup"
require "goliath"
require "grape"
require File.expand_path('../config/environment.rb', __FILE__)

class Application < Goliath::API
  def response(env)
    EpttAPI.call(env)
  end
end