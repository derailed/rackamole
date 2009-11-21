begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'rackamole'

task :default => 'spec:run'

PROJ.name            = 'rackamole'
PROJ.authors         = 'Fernand Galiana'
PROJ.email           = 'fernand.galiana@gmail.com'
PROJ.url             = 'http://rackamole.liquidrail.com'
PROJ.version         = Rackamole::VERSION
PROJ.spec.opts       << '--color'
PROJ.ruby_opts       = %w[-W0]
PROJ.readme          = 'README.rdoc'
PROJ.rcov.opts       = ["--sort", "coverage", "-T", '-x mongo']

# Dependencies
depend_on "logging"      , ">= 1.2.2"
depend_on "hitimes"      , ">= 1.0.3"
depend_on "mongo"        , ">= 0.17.1"
depend_on "darkfish-rdoc", ">= 1.1.5"