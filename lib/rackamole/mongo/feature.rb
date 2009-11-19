module Rackamole::Mongo
  class Feature
    include MongoMapper::Document
  
    key :controller, String, :required => false
    key :action    , String, :required => false
    key :context   , String, :required => false
    key :app_name  , String, :required => true
    timestamps!
      
    many :logs, :class_name => 'Rackamole::Mongo::Log'
  end
end