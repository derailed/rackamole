require 'rubygems'
require 'rack'
require 'rack/test'

require 'active_support'
require 'action_pack'

require File.join(File.dirname(__FILE__), %w[.. lib rackamole])

Spec::Runner.configure do |config|
end