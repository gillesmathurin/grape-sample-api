require 'grape'
require 'json'
require 'grape-swagger'
require 'csv'
require 'date'

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

  get '/hello' do
   { :total => Users.count, :data => Users.all.map { |e| { :id => e.id, :name => e.last_name } } }
  end

  desc "synchronize datas between client and server"
  post 'sync' do
    parsed_datas = JSON.parse(params[:local_database])
  end

  desc "imort trainees"
  params do
        requires :file_content, type: String, desc: "list trainees"
  end
  post 'import_stars' do
     error = "ok"

      courses = DB[:courses]
      trainees = DB[:trainees]
      CSV::Converters[:blank_to_nil] = lambda do |field|
        field && field.empty? ? nil : field
      end
        begin
         CSV.foreach('/Users/Michelin/Downloads/CLASSSTARTSApr01-2.csv',{:headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil] }) do |row|
          if error == "ok"
            error = row[:COURSE]
          end
        unless  row['COURSE'].nil? || row['COURSE'].empty? || row['CATEGORY'] == 'maintenance' || row['VARIANTS'] == 'PRAC' || row['VARIANTS'] = 'PRAC-ONLY'
            error = "parsed"
            start_date = row['STARTDATE'].gsub('/','_')
            end_date = row['ENDDATE']
            codename = row['COURSE'].gsub(/['"\\\x0]/,'\\\\\0')
            name = row['COURSENAME'].gsub(/['"\\\x0]/,'\\\\\0')
            course_id = "#{codename}_#{start_date}".gsub(/['"\\\x0]/,'\\\\\0')
            category = row['CATEGORY'].gsub(/['"\\\x0]/,'\\\\\0')
            variants = row['VARIANTS'].gsub(/['"\\\x0]/,'\\\\\0')
            start_date = DateTime.strptime(start_date, '%m/%d/%Y')
            end_date = DateTime.strptime(end_date, '%m/%d/%Y')

            #replace or insert a course
            b_classification = "";
            if ((codename =~ /B1/) && ( codename =~ /B2/))
                b_classification = "B1/B2"
            elsif (codename =~ /B1/)
                b_classification = "B1"
            elsif (codename =~ /B2/)
                 b_classification = "B2"
            elsif ((name =~ /B1/) && ( name =~ /B2/))
                b_classification = "B1/B2"
            elsif (name =~ /B1/)
                b_classification = "B1"
            elsif (name =~ /B2/)
                b_classification = "B2"
            end
            courses.on_duplicate_key_updat.insert({:id => course_id},{:id => course_id ,
              :codename  => codename,
              :name => name,
               :category => category,
               :variants => variants,
               :start_date => start_date ,
               :end_date => end_date , :b_classification => b_classification})

            #insert a trainee
            first_name = row['FIRSTNAME']
            last_name = row['LASTNAME']

            login = "#{first_name}_#{last_name}"
            login = login.gsub(/[^A-Za-z0-9]/,'')
            login = login.downcase

            last_name = last_name.gsub(/['"\\\x0]/,'\\\\\0')
            first_name = first_name.gsub(/['"\\\x0]/,'\\\\\0')
            email = row['EMAIL'].gsub(/['"\\\x0]/,'\\\\\0')
            company = row['COMPANYNAME'].gsub(/['"\\\x0]/,'\\\\\0')


            trainees.on_duplicate_key_updat.insert({:login => login},
              {:first_name => first_name ,
                :last_name  => last_name,
                :login => login,
                :role => 'trainee',
               :email => email,
               :company =>  company})

            id_reservation = row['RESERVATION']
            DB.run "INSERT INTO reservations (id, user_id, course_id) (SELECT '#{id_reservation}', id, '#{course_id}' FROM users WHERE login='#{login}') ON DUPLICATE KEY UPDATE id='#{id_reservation}'";
        else
           {state: 'empty'}
        end
      end
    rescue  CSV::MalformedCSVError => er
      error = er.message

  end
      {
        :error => error,
        :users => Users.all.map { |e| { :id => e.id, :first_name => e.first_name , :last_name => e.last_name, :login => e.login, :role => e.role, :password_clear => e.password_clear, :company => e.company} },
        :courses => Courses.all.map { |e| { :id => e.id, :codename => e.codename , :name => e.name, :category => e.category, :variants => e.variants, :start_date => e.start_date, :end_date => e.end_date, :b_classification => e.b_classification} },
        :reservations => Reservations.all.map { |e| { :id => e.id, :course_id => e.course_id , :user_id => e.user_id, :group => e.group, :user_modified => e.user_modified} }
      }
  end


end
