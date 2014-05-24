require 'grape'
require 'json'
require 'active_support'
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

    keys = ["courses", "reservations", "results", "logbook_notes", "evaluations", "practical_exercises"]

    keys.each do |key|
      model = key.camelize.constantize
      p model
      model.unrestrict_primary_key

      if parsed_datas[key] && parsed_datas[key].any?

        unless key == "courses"
          # Update or create model records
          parsed_datas[key].each do |hash|
            if hash["user_modified"] == "1"
              record_id = hash["id"]
              model[record_id].nil? ? model.create(hash) : model.update(hash)
            end
          end
        else
          # Delete courses marked for destroy if any
          parsed_datas["courses"].each do |course|
            if course["user_deleted"] == 1
              course_id = course["id"]
              Courses.where(id: course_id).delete
              reservations = Reservations.where(course_id: course_id)
              reservations.logbook_notes.dataset.delete
              reservations.dataset.delete
            end
          end
        end

      end
    end
  end

end