require File.expand_path(File.join(File.dirname(__FILE__), %w[.. spec_helper]))

require 'ostruct'

# Test application...
class Fred
  def rescue_action_in_public( exception )
  end

  def rescue_action_locally( exception )
  end

  def request
    @request ||= OpenStruct.new( :env => {} )
  end

  def self.alias_method_chain(target, feature)
    alias_method "#{target}_without_#{feature}", target
    alias_method target, "#{target}_with_#{feature}"
  end

  include Rackamole::Interceptor      
end    

describe Rackamole::Interceptor do        
  it "should include the correct methods" do
    Fred.instance_methods.should be_include( :rescue_action_locally_without_mole )    
    Fred.private_instance_methods.should be_include( :rescue_action_locally_with_mole )
    
    Fred.instance_methods.should be_include( :rescue_action_in_public_without_mole )    
    Fred.private_instance_methods.should be_include( :rescue_action_in_public_with_mole )
  end

  it "should set the env correctly when a local exception is raised" do
    fred = Fred.new
    fred.send( :rescue_action_locally, "Fred" )
    fred.request.env['mole.exception'].should == "Fred"
  end
    
  it "should set the env correctly when an exception is raised" do
    fred = Fred.new
    fred.send( :rescue_action_in_public, "Fred" )
    fred.request.env['mole.exception'].should == "Fred"
  end
end
