require 'grape'
require 'json'
require 'grape-swagger'
require 'csv'
require 'date'
require 'time'
require 'active_support'
require 'yaml'
require 'aws-sdk'
require 'zip'
require 'find'
require_relative 'models'

class EpttAPI < Grape::API
  prefix 'api'
  format :json
  # version 'v1'
  rescue_from :all

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
          hash["attempts"].each { |attempt| Attempt.create(attempt) } if hash.has_key?("attempts")
        end
      end
    end
    # Delete courses marked for destroy
    def delete_courses(courses_array)
      courses_array.each do |course|
        course_id = course["id"]
        if course["user_deleted"] == "1"
          Course.where(id: course_id).delete
          reservations = Reservation.where(course_id: course_id)
          reservations.each { |r| r.logbook_notes.delete }
          reservations.delete
        end
      end
    end

    def delete_practical_exercises_and_associated_models(id)
      PracticalExercise.where(id: id).delete
      Result.where(practical_exercise_id: id).delete
      TheoryLink.where(practical_exercise_id: id).delete
      Condition.where(practical_exercise_id: id).delete
      Link.where(practical_exercise_id: id).delete
      Evaluation.where(practical_exercise_id: id).delete
    end

    def get_s3_bucket
      s3_credentials ||= YAML.load_file(File.join("config", "s3.yml"))
      s3 = AWS::S3.new(s3_credentials.merge(verify_response_body_content_length: false))
      return s3.buckets[s3_credentials["s3_bucket"]]
    end

    def get_bucket_files_and_url
      arr = []
      get_s3_bucket.objects.each {|obj| arr<<{filename: obj.key, url: obj.public_url} }
      arr
    end

    # def get_bucket_files_in_zip
    #   dir_path = File.expand_path('../tmp/files_to_sync',__FILE__)
    #   Dir.mkdir(dir_path) unless Dir.exist?(dir_path)
    #   files_urls = get_bucket_files_and_url
    #   files_urls.each do |hash|
    #     fullpath = dir_path + '/' + hash[:filename]
    #     unless File.exist?(fullpath)
    #       tempfile = File.new(fullpath, "wb+", encoding: 'ascii-8bit')
    #       begin
    #           obj = get_s3_bucket.objects[hash[:filename]]
    #           obj.read { |chunk| tempfile.write(chunk) }
    #       rescue Exception => e
    #       ensure
    #         tempfile.close
    #       end
    #     end
    #   end
    #   zipfile_name = File.expand_path("../tmp/files_to_sync.zip",__FILE__)
    #   unless File.exist?(zipfile_name)
    #     Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
    #       Dir[File.join(dir_path, '*')].each do |file|
    #         begin
    #           zipfile.add(file.sub((dir_path+'/'), ''), file)
    #         rescue Zip::EntryExistsError => e
    #           puts e.message
    #         end
    #       end
    #     end
    #   end
    #   return zipfile_name
    # end

    def update_practical_exercises_and_associated_models(pe)
      pe_id = pe["id"]
      pe_wo_links_and_theory_links = pe.reject {|k,v| k == "links" || k == "theory_links"}
      PracticalExercise[pe_id].nil? ? PracticalExercise.create(pe_wo_links_and_theory_links) : PracticalExercise[pe_id].update(pe_wo_links_and_theory_links)

      if pe.has_key?("theory_links")
        TheoryLink.unrestrict_primary_key
        pe["theory_links"].each do |theory_link|
          theory_link_id = theory_link["id"]
          if theory_link["user_modified"] == "1"
            TheoryLink[theory_link_id].nil? ? TheoryLink.create(theory_link) : TheoryLink[theory_link_id].update(theory_link)
          end
        end
      end

      if pe.has_key?("links")
        Link.unrestrict_primary_key
        # create S3 session object and get bucket
        s3_bucket = get_s3_bucket
        pe["links"].each do |link|
          link_id = link["id"]
          Link[link_id].delete if link["user_deleted"] == "1"
          if link["user_modified"] == "1"
            Link[link_id].nil? ? Link.create(link) : Link[link_id].update(link)
            if link["filename"].present?
              filename = link["filename"]
              # File to upload to S3 should be in params["#{link["filename"]}"]
              puts params[filename]
              s3_bucket.objects[filename]
            end
          end
        end
      end
    end

    def map_models_to_hash(model)
      result = []
      model.all.each do |r|
        h = {}
        r.columns.each { |column| h[column] = r.send(column) }
        if model == Evaluation
          h[:attempts] = r.attempts.map { |a| {id: a.id, date_attempt: a.date_attempt, instructor_first_name: a.instructor_first_name, instructor_last_name: a.instructor_last_name, result: a.result, evaluation_id: a.evaluation_id} }
        end
        if model == PracticalExercise
          h[:links] = r.links.map { |l| {id: l.id, practical_exercise_id: l.practical_exercise_id, name: l.name, filename: l.filename, user_modified: l.user_modified, user_deleted: l.user_deleted} }
          h[:theory_links] = r.theory_links.map { |tl| {id: tl.id, practical_exercise_id: tl.practical_exercise_id, name: tl.name, reference: tl.reference, user_modified: tl.user_modified} }
        end
        result << h
      end
      return result
    end
  end

  before do
    header "Access-Control-Allow-Origin", "*"
    header "Access-Control-Request-Method", "*"
  end

  desc "api test endpoint /hello"
  get 'hello' do
    {hello: "world"}
  end

  desc "synchronize datas between client and server"
  post 'sync' do
    if params[:local_database]
      parsed_datas = JSON.parse(params[:local_database])
      keys = ["courses", "reservations", "results", "logbook_notes", "evaluations", "practical_exercises"]

      keys.each do |key|
        model = key.singularize.camelize.constantize # transform string into Class name
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
      users: map_models_to_hash(User),
      aircrafts: map_models_to_hash(Aircraft),
      courses: map_models_to_hash(Course),
      reservations: map_models_to_hash(Reservation),
      chapters: map_models_to_hash(Chapter),
      results: map_models_to_hash(Result),
      logbook_notes: map_models_to_hash(LogbookNote),
      evaluations: map_models_to_hash(Evaluation),
      practical_exercises: map_models_to_hash(PracticalExercise),
      files_to_sync: get_bucket_files_and_url
    }
  end

  desc "download zip archive of files_to_sync"
  get 'zip_file' do
    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=all.zip"
    env['api.format'] = :binary # to try if failing like that
    path = get_s3_bucket.objects['all.zip'].public_url
    File.open(path, "rb").read
  end

  desc "import trainees"
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
        :users => User.all.map { |e| { :id => e.id, :first_name => e.first_name , :last_name => e.last_name, :login => e.login, :role => e.role, :password_clear => e.password_clear, :company => e.company} },
        :courses => Course.all.map { |e| { :id => e.id, :codename => e.codename , :name => e.name, :category => e.category, :variants => e.variants, :start_date => e.start_date, :end_date => e.end_date, :b_classification => e.b_classification} },
        :reservations => Reservation.all.map { |e| { :id => e.id, :course_id => e.course_id , :user_id => e.user_id, :group => e.group, :user_modified => e.user_modified} }
      }
  end

end
