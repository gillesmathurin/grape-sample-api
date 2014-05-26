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
        Courses.dataset.delete
        Reservations.dataset.delete
        LogbookNotes.dataset.delete
        Results.dataset.delete
        PracticalExercises.dataset.delete
        TheoryLinks.dataset.delete
        courses_reservations_logbook[:courses].each do |course_params|
          Courses.unrestrict_primary_key
          Courses.create(course_params)
        end
      end

      it "delete the courses marked for delete, their reservations and logbook_notes" do
        pending("Not a needed feature")
        Courses.count.should == 3
        post "/api/sync", local_database: courses_reservations_logbook.to_json
        last_response.status.should == 201
      end

      it "creates the reservation" do
        post "/api/sync", local_database: courses_reservations_logbook.to_json
        last_response.status.should == 201
        Reservations.count.should == 1
      end

      it "creates or updates the results" do
        post "/api/sync", local_database: results_datas.to_json
        last_response.status.should == 201
        Results.count.should == 2
      end

      it "creates or updates the logbook notes" do
        post "/api/sync", local_database: logbook_notes_datas.to_json
        last_response.status.should == 201
        LogbookNotes.count.should == 1
      end

      it "deletes the practical_exercises marked for destroy" do
        post "/api/sync", local_database: practical_exercises_datas.to_json
        last_response.status.should == 201
        PracticalExercises.count.should == 2
        TheoryLinks.count.should == 2
        post "/api/sync", local_database: practical_exercises_to_delete.to_json
        PracticalExercises.count.should == 0
        TheoryLinks.count.should == 0
      end

      it "saves the practical exercises links" do
        
      end
    end
  end
end