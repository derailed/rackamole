require File.expand_path(File.join(File.dirname(__FILE__), %w[.. .. spec_helper]))
require 'chronic'

describe Rackamole::Stash::Fault do
  before( :all ) do
    @now = Chronic.parse( "11/27/2009" )
  end
  
  it "should record fault information correctly" do
    begin
      raise "Oh snap!"
    rescue => boom
      fault = Rackamole::Stash::Fault.new( "/", boom.backtrace.first, @now )
      fault.send( :path ).should      == "/"
      fault.send( :stack ).should     == File.join( File.dirname(__FILE__), "fault_spec.rb:11:in `block (2 levels) in <top (required)>'" )
      fault.send( :timestamp ).should == @now
    end
  end
end
  