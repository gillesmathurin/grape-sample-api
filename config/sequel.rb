require 'sequel'

# Connecting to database
DB = Sequel.connect('mysql2://root:password@localhost/eptt', max_connections: 4) if ENV['RACK_ENV'] == "development"
DB = Sequel.connect('mysql2://root:password@localhost/eptt_test', max_connections: 4) if ENV['RACK_ENV'] == "test"
DB = Sequel.connect('mysql2://531485_eptt:p3W7bg6S@174.143.28.26/531485_eptt', max_connections: 4) if ENV['RACK_ENV'] == "production"
