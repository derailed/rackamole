begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

task :default      => 'spec:run'
task 'gem:release' => 'spec:run'

Bones {
  name        'rackamole'
  authors     'Fernand Galiana'
  readme_file 'README.rdoc'
  email       'fernand.galiana@gmail.com'
  url         'http://www.rackamole.com'
  # spec.opts   %w[--color]
  ruby_opts   %w[-W0]
  
  # Dependencies
  depend_on "logging"      , ">= 1.2.2"
  depend_on "hitimes"      , ">= 1.0.3"
  depend_on "mongo"        , ">= 1.0.1"
  depend_on "bson"         , ">= 1.0.1"
  depend_on "bson_ext"     , ">= 1.0.1"
  depend_on "chronic"      , ">= 0.2.3"
  depend_on "twitter4r"    , ">= 0.3.0"
  depend_on "erubis"       , ">= 2.6.0"
  depend_on "mail"         , ">= 2.1.3"
  depend_on "ruby-growl"   , ">= 2.0"  
}