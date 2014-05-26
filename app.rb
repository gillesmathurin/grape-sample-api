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
    # Update or create model records
    def update_or_create_records_for_model(attributes_hash_array, model)
      attributes_hash_array.each do |hash|
        record_id = hash["id"]
        if hash["user_modified"] == "1"
          model[record_id].nil? ? model.create(hash) : model[record_id].update(hash)
          hash["attempts"].each { |attempt| Attempts.create(attempt) } if hash.has_key?("attempts")
        end
      end
    end
    # Delete courses marked for destroy
    def delete_courses(courses_array)
      courses_array.each do |course|
        course_id = course["id"]
        if course["user_deleted"] == "1"
          Courses.where(id: course_id).delete
          reservations = Reservations.where(course_id: course_id)
          reservations.each { |r| r.logbook_notes.delete }
          reservations.delete
        end
      end
    end

    def delete_practical_exercises_and_associated_models(id)
      PracticalExercises.where(id: id).delete
      Results.where(practical_exercise_id: id).delete
      TheoryLinks.where(practical_exercise_id: id).delete
      Conditions.where(practical_exercise_id: id).delete
      Links.where(practical_exercise_id: id).delete
      Evaluations.where(practical_exercise_id: id).delete
    end

    def update_practical_exercises_and_associated_models(pe)
      pe_id = pe["id"]
      pe_wo_links_and_theory_links = pe.reject {|k,v| k == "links" || k == "theory_links"}
      PracticalExercises[pe_id].nil? ? PracticalExercises.create(pe_wo_links_and_theory_links) : PracticalExercises[pe_id].update(pe_wo_links_and_theory_links)

      if pe.has_key?("theory_links")
        TheoryLinks.unrestrict_primary_key
        pe["theory_links"].each do |theory_link|
          theory_link_id = theory_link["id"]
          if theory_link["user_modified"] == "1"
            TheoryLinks[theory_link_id].nil? ? TheoryLinks.create(theory_link) : TheoryLinks[theory_link_id].update(theory_link)
          end
        end
      end

      if pe.has_key?("links")
        Links.unrestrict_primary_key
        pe["links"].each do |link|
          link_id = link["id"]
          Links[link_id].delete if link["user_deleted"] == "1"
          if link["user_modified"] == "1"
            Links[link_id].nil? ? Links.create(link) : Links[link_id].update(link)
            if link["filename"].present?
              puts params["#{link["filename"]}"]
            end
          end
        end
      end
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
      model = key.camelize.constantize # transform string into Class name
      model.unrestrict_primary_key # allow to update id attribute

      if parsed_datas[key] && parsed_datas[key].any?
        unless key == "courses" || key == "practical_exercises"
          update_or_create_records_for_model(parsed_datas[key], model)
        else
          delete_courses(parsed_datas["courses"]) if key == "courses"
          if key == "practical_exercises"
            parsed_datas["practical_exercises"].each do |pe|
              pe_id = pe["id"]
              delete_practical_exercises_and_associated_models(pe_id) if pe["user_deleted"] == "1"
              update_practical_exercises_and_associated_models(pe) if pe["user_modified"] == "1"
            end
          end
        end
      end

    end
  end  

end