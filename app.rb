require 'grape'
require 'json'

class EpttAPI < Grape::API
  prefix 'api'
  version 'v1'
  format :json

  get 'hello' do
    {hello: 'world'}
  end  
end