require File.expand_path(File.join(File.dirname(__FILE__), %w[.. .. spec_helper]))
require 'chronic'

describe Rackamole::Stash::Perf do
  before( :all ) do
    @now = Chronic.parse( "11/27/2009" )
  end
  
  it "should record perf information correctly" do
    perf = Rackamole::Stash::Perf.new( "/", 10.0, @now )
    perf.send( :path ).should      == "/"
    perf.send( :elapsed ).should   == 10.0
    perf.send( :timestamp ).should == @now
  end
end
  