require_relative 'config/sequel'

# require "bcrypt"
# require "securerandom"
require "active_support/core_ext/date_time/calculations"

class Users < Sequel::Model
end

class Aircrafts < Sequel::Model
end

class Attempts < Sequel::Model
end

class Chapters < Sequel::Model
end

class Conditions < Sequel::Model
end

class Courses < Sequel::Model
end

class Evaluations < Sequel::Model
end

class Links < Sequel::Model
end

class LogbookNotes < Sequel::Model
end

class PracticalExercises < Sequel::Model
end

class Reservations < Sequel::Model
end

class Results < Sequel::Model
end

class TheoryLinks < Sequel::Model
  
end