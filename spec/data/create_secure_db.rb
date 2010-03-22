# BOZO !! Rake task
require 'rubygems'
require 'mongo'

con = Mongo::Connection.new( 'localhost' )
db  = con.db( 'sec_app_test_mdb' )
db.add_user( 'fred', 'letmein' )