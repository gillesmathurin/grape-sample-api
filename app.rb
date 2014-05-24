require 'grape'
require 'json'
require_relative 'models'

class EpttAPI < Grape::API
  prefix 'api'
  format :json
  # version 'v1'

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
  post 'sync' do
    parsed_datas = JSON.parse(params[:local_database])
  end
end