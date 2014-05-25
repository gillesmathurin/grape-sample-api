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
      model.unrestrict_primary_key

      if parsed_datas[key] && parsed_datas[key].any?

        unless key == "courses" || key == "practical_exercises"
          # Update or create model records
          parsed_datas[key].each do |hash|
            record_id = hash["id"]
            if hash["user_modified"] == "1"
              model[record_id].nil? ? model.create(hash) : model[record_id].update(hash)
              hash["attempts"].each { |attempt| Attempts.create(attempt) } if hash.has_key?("attempts")
            end
          end
        else
          # Delete courses marked for destroy if any
          if key == "courses"
            parsed_datas["courses"].each do |course|
              course_id = course["id"]
              if course["user_deleted"] == "1"
                Courses.where(id: course_id).delete
                reservations = Reservations.where(course_id: course_id)
                reservations.each { |r| r.logbook_notes.delete }
                reservations.delete
              end
            end
          end
          # Delete or Update practical exercises and associated models
          if key == "practical_exercises"
            parsed_datas["practical_exercises"].each do |pe|
              pe_id = pe["id"]

              if pe["user_deleted"] == "1"
                PracticalExercises.where(id: pe_id).delete
                Results.where(id: pe_id).delete
                TheoryLinks.where(id: pe_id).delete
                Conditions.where(id: pe_id).delete
                Links.where(id: pe_id).delete
                Evaluations.where(id: pe_id).delete
              end

              if pe["user_modified"] == "1"
                PracticalExercises[pe_id].nil? ? PracticalExercises.create(pe) : PracticalExercises[pe_id].update(pe)

                if pe.has_key?("theory_links")
                  pe["theory_links"].each do |theory_link|
                    theory_link_id = theory_link["id"]
                    if theory_link["user_modified"] == "1"
                      TheoryLinks[theory_link_id].nil? ? TheoryLinks.create(theory_link) : TheoryLinks.update(theory_link)
                    end
                  end
                end

                if pe.has_key?("links")
                  pe["links"].each do |link|
                    link_id = link["id"]
                    Links[link_id].delete if link["user_deleted"] == "1"
                    if link["user_modified"] == "1"
                      Links[link_id].nil? ? Links.create(link) : Links.update(link)
                    end
                  end
                  
                end
              end
            end
          end
        end

      end
    end
  end

end