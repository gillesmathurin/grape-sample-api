require_relative 'config/sequel'

# require "bcrypt"
# require "securerandom"
require "active_support/core_ext/date_time/calculations"

class User < Sequel::Model
  one_to_many :reservations
  one_to_many :evaluations
  one_to_many :results
end

class Aircraft < Sequel::Model
end

class Attempt < Sequel::Model
  many_to_one :evaluation
end

class Chapter < Sequel::Model
end

class Condition < Sequel::Model
  many_to_one :practical_exercise
end

class Course < Sequel::Model
  unrestrict_primary_key
  one_to_many :reservations
  one_to_many :results
  attr_accessor :user_deleted
end

class Evaluation < Sequel::Model
  one_to_many :attempts
  many_to_one :practical_exercise
  many_to_one :user
end

class Link < Sequel::Model
  many_to_one :practical_exercise
end

class LogbookNote < Sequel::Model
  many_to_one :reservation
end

class PracticalExercise < Sequel::Model
  one_to_many :evaluations
  one_to_many :conditions
  one_to_many :links
  one_to_many :results
  one_to_many :theory_links
end

class Reservation < Sequel::Model
  many_to_one :course
  many_to_one :user
  one_to_many :logbook_notes
end

class Result < Sequel::Model
  many_to_one :practical_exercise
  many_to_one :user
  many_to_one :course
end

class TheoryLink < Sequel::Model
  many_to_one :practical_exercise
end
