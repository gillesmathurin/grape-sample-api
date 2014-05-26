require 'grape'
require 'json'
require 'grape-swagger'
require 'csv'
require 'date'
require 'time'
require 'active_support'
require 'yaml'
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

    def get_s3_bucket
      s3_credentials ||= YAML.load_file(File.join("config", "s3.yml"))
      s3 = AWS::S3.new(s3_credentials.merge(verify_response_body_content_length: false))
      return s3.buckets[s3_credentials["s3_bucket"]]
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
        # create S3 session object and get bucket
        s3_bucket = get_s3_bucket
        pe["links"].each do |link|
          link_id = link["id"]
          Links[link_id].delete if link["user_deleted"] == "1"
          if link["user_modified"] == "1"
            Links[link_id].nil? ? Links.create(link) : Links[link_id].update(link)
            if link["filename"].present?
              # File to upload to S3 should be in params["#{link["filename"]}"]
              # TODO : 
            end
          end
        end
      end
    end
  end

  before do
    header "Access-Control-Allow-Origin", "*"
  end

  desc "testing endpoint"
  get 'hello' do
    {hello: "world"}
  end

  desc "synchronize datas between client and server"
  post 'sync' do
    if params[:local_database]
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

    # Response
    {
      users: Users.all,
      aircrafts: Aircrafts.all,
      courses: Courses.all,
      reservations: Reservations.all,
      chapters: Chapters.all,
      results: Results.all,
      logbook_notes: LogbookNotes.all,
      evaluations: Evaluations.all
      # TODO : include attempts into evaluations
      # TODO : include links and theory_links into practical_exercises
      # TODO : include files list into response
    }
  end  


  desc "imort trainees"
  params do
        requires :file_content, type: String, desc: "list trainees"
  end
  post 'import_stars' do
      csv_raw = params[:file_content]
      error = ""
      query = ""
      courses = DB[:courses]
      trainees = DB[:trainees]

      CSV::Converters[:blank_to_nil] = lambda do |field|
        field && field.empty? ? nil : field
      end

      begin
      CSV.parse(csv_raw,{:headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil]}) do |row|
        if row.to_hash.length > 0
            unless  row[:course].nil? || row[:course].empty? || row[:category] == 'maintenance' || row[:variants].to_s =~ /PRAC|PRAC-ONLY/i
            error = "parsed"
            start_date = row[:startdate].to_s.gsub('/','_')
            end_date = row[:enddate]
            codename = row[:course].to_s.gsub(/['"\\\x0]/,'\\\\\0')
            name = row[:coursename].to_s.gsub(/['"\\\x0]/,'\\\\\0')
            course_id = "#{codename}_#{start_date}".gsub(/['"\\\x0]/,'\\\\\0')
            category = row[:category].to_s.gsub(/['"\\\x0]/,'\\\\\0')
            variants = row[:variants].to_s.gsub(/['"\\\x0]/,'\\\\\0')
            start_date = DateTime.strptime(row[:startdate], '%m/%d/%Y')
            end_date = DateTime.strptime(end_date, '%m/%d/%Y')

            #replace or insert a course
            b_classification = " ";

            if ((codename.include? "B1/B2") || (name.include? "B1/B2"))
                b_classification = "B1/B2"
            elsif ((codename.include? "B1") || (name.include? "B1"))
                b_classification = "B1"
            elsif((codename.include? "B2") || (name.include? "B2"))
                 b_classification = "B2"
            end
            query = "INSERT INTO courses (id, codename, name, category, variants, start_date, end_date, b_classification) VALUES ('#{course_id}', '#{codename}', '#{name}', '#{category}','#{variants}','#{start_date}','#{end_date}', '#{b_classification}') ON DUPLICATE KEY UPDATE id='#{course_id}';";
            DB.run(query)
            #insert a trainee
            first_name = row[:firstname]
            last_name = row[:lastname]

            login = "#{first_name}_#{last_name}"
            login = login.to_s.gsub(/[^A-Za-z0-9]/,'')
            login = login.downcase

            last_name = last_name.to_s.gsub(/['"\\\x0]/,'\\\\\0')
            first_name = first_name.to_s.gsub(/['"\\\x0]/,'\\\\\0')
            email = row[:email].to_s.gsub(/['"\\\x0]/,'\\\\\0')
            company = row[:companyname].to_s.gsub(/['"\\\x0]/,'\\\\\0')

            query ="INSERT INTO users (first_name, last_name, login, role, email, company) VALUES ('#{first_name}', '#{last_name}', '#{login}', 'trainee', '#{email}', '#{company}') ON DUPLICATE KEY UPDATE login='#{login}'";
            DB.run(query)
            #insert a reservation
            id_reservation = row[:reservation]
            DB.run "INSERT INTO reservations (id, user_id, course_id) (SELECT '#{id_reservation}', id, '#{course_id}' FROM users WHERE login='#{login}') ON DUPLICATE KEY UPDATE id='#{id_reservation}'";
          end
        end
      end
      rescue CSV::MalformedCSVError => e
        puts "failed to parse line with random quote char #{e}"
        error = e
      end
      # Il n'y a pas une façon plus simple de retourner la réponse ?
      {
        :error => error,
        :users => Users.all.map { |e| { :id => e.id, :first_name => e.first_name , :last_name => e.last_name, :login => e.login, :role => e.role, :password_clear => e.password_clear, :company => e.company} },
        :courses => Courses.all.map { |e| { :id => e.id, :codename => e.codename , :name => e.name, :category => e.category, :variants => e.variants, :start_date => e.start_date, :end_date => e.end_date, :b_classification => e.b_classification} },
        :reservations => Reservations.all.map { |e| { :id => e.id, :course_id => e.course_id , :user_id => e.user_id, :group => e.group, :user_modified => e.user_modified} }
      }
  end

end
