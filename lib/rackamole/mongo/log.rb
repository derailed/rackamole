module Rackamole::Mongo
  class Log
    include MongoMapper::Document
  
    key :feature_id , String, :required => true
    key :perf_issue , Boolean, :required => true, :default => false
    key :type       , String , :required => true, :default => 'Feature'
    key :ip         , String , :required => true
    key :browser    , String , :required => true
    key :method     , String , :required => true
    key :path       , String , :required => true
    key :url        , String , :required => true
    
    key :user_id    , Integer, :required => false, :default => -1
    key :user_name  , String , :required => false, :default => "Unknown"
    key :session    , Hash   , :required => false
    key :router_info, Hash   , :required => false
    timestamps!
      
    belongs_to :feature, :class_name => 'Rackamole::Mongo::Feature'
  end
end