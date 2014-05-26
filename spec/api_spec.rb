require "spec_helper"
require_relative "json_fixtures"

describe EpttAPI do
  include Rack::Test::Methods
  include JsonFixtures

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

    describe "POST /api/sync" do
      before(:each) do
        Course.dataset.delete
        Reservation.dataset.delete
        LogbookNote.dataset.delete
        Result.dataset.delete
        PracticalExercise.dataset.delete
        TheoryLink.dataset.delete
        courses_reservations_logbook[:courses].each do |course_params|
          Course.unrestrict_primary_key
          Course.create(course_params)
        end
      end

      it "delete the courses marked for delete, their reservations and logbook_notes" do
        pending("Not a needed feature")
        Course.count.should == 3
        post "/api/sync", local_database: courses_reservations_logbook.to_json
        last_response.status.should == 201
      end

      it "creates the reservation" do
        post "/api/sync", local_database: courses_reservations_logbook.to_json
        last_response.status.should == 201
        Reservation.count.should == 1
      end

      it "creates or updates the results" do
        post "/api/sync", local_database: results_datas.to_json
        last_response.status.should == 201
        Result.count.should == 2
      end

      it "creates or updates the logbook notes" do
        post "/api/sync", local_database: logbook_notes_datas.to_json
        last_response.status.should == 201
        LogbookNote.count.should == 1
      end

      it "deletes the practical_exercises marked for destroy" do
        post "/api/sync", local_database: practical_exercises_datas.to_json
        last_response.status.should == 201
        PracticalExercise.count.should == 2
        TheoryLink.count.should == 2
        post "/api/sync", local_database: practical_exercises_to_delete.to_json
        PracticalExercise.count.should == 0
        TheoryLink.count.should == 0
      end

      it "saves the practical exercises links" do
        
      end
    end
  end
end