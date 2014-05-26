require_relative 'config/sequel'

# require "bcrypt"
# require "securerandom"
require "active_support/core_ext/date_time/calculations"

class Users < Sequel::Model
  one_to_many :reservations
  one_to_many :evaluations
  one_to_many :results

end

class Aircrafts < Sequel::Model
end

class Attempts < Sequel::Model
  many_to_one :evaluation
end

class Chapters < Sequel::Model
end

class Conditions < Sequel::Model
  many_to_one :practical_exercise
end

class Courses < Sequel::Model
  unrestrict_primary_key
  one_to_many :reservations
  one_to_many :results
  attr_accessor :user_deleted
end

class Evaluations < Sequel::Model
  one_to_many :attempts
  many_to_one :practical_exercise
  many_to_one :user
end

class Links < Sequel::Model
  many_to_one :practical_exercise
end

class LogbookNotes < Sequel::Model
  many_to_one :reservation
end

class PracticalExercises < Sequel::Model
  one_to_many :evaluations
  one_to_many :conditions
  one_to_many :links
  one_to_many :results
  one_to_many :theory_links
end

class Reservations < Sequel::Model
  many_to_one :course
  many_to_one :user
  one_to_many :logbook_notes
end

class Results < Sequel::Model
  many_to_one :practical_exercise
  many_to_one :user
  many_to_one :course
end

class TheoryLinks < Sequel::Model
  many_to_one :practical_exercise
end
