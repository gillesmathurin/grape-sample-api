require 'sequel'

# Connecting to database
DB = Sequel.connect('mysql2://531485_eptt:p3W7bg6S@174.143.28.26/531485_eptt', max_connections: 4, logger: Logger.new('log/db.log'))