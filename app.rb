require 'grape'
require 'json'
require_relative 'models'

class EpttAPI < Grape::API
  prefix 'api'
  # version 'v1'
  format :json

  helpers do
    # making the logger available in the endpoint context
    def logger
      EpttAPI.logger
    end
  end

  get 'hello' do
    {hello: 'world'}
  end

  desc "synchronize datas between client and server"
  get 'sync' do
    # 
  end

  des
  post
end