require "spec_helper"

describe EpttAPI do
  include Rack::Test::Methods

  def app
    EpttAPI
  end

  describe EpttAPI do
    describe 'GET /api/hello' do
      it "says hello to the world" do
        get "/api/hello"
        last_response.status.should == 200
        JSON.parse(last_response.body)["hello"].should == "world"
      end
    end
  end
end