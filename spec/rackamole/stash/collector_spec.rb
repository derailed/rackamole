require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])
require 'chronic'

describe Rackamole::Stash::Collector do
  before( :each ) do
    @now       = Chronic.parse( "11/27/2009" )
    @collector = Rackamole::Stash::Collector.new( "Fred", "test" )
  end

  describe "#stash" do  
    it "should record fault information correctly" do
      begin
        raise "Oh snap!"
      rescue => boom
        @collector.stash_fault( "/", boom.backtrace.first, @now )
        @collector.send( :faults ).size.should == 1
      
        fault = @collector.send( :find_fault, "/", boom.backtrace.first )          
        fault.should_not                be_nil
        fault.send( :path ).should      == "/"
        fault.send( :stack ).should     == "./spec/rackamole/stash/collector_spec.rb:13"
        fault.send( :timestamp ).should == @now
      end
    end

    it "should record perf information correctly" do
      @collector.stash_perf( "/", 10.0, @now )
      @collector.send( :perfs ).size.should == 1
    
      perf = @collector.send( :find_perf, "/" )          
      perf.should_not                be_nil
      perf.send( :path ).should      == "/"
      perf.send( :elapsed ).should   == 10.0
      perf.send( :timestamp ).should == @now
    end
  end
  
  describe "#expire" do
    before( :all ) do
      @now       = Chronic.parse( "11/27/2009" )
      @yesterday = Chronic.parse( "yesterday", :now => @now )
    end
    
    it "should expire fault correctly" do
      begin
        raise "Oh snap!"
      rescue => boom
        @collector.stash_fault( "/", boom.backtrace.first, @yesterday )
        @collector.send( :faults ).size.should == 1
        @collector.expire_faults!
        @collector.send( :faults ).size.should == 0
      end
    end
    
    it "should expire perf correctly" do
      @collector.stash_perf( "/", 10, @yesterday )
      @collector.send( :perfs ).size.should == 1
      @collector.expire_perfs!
      @collector.send( :perfs ).size.should == 0
    end
  end
  
end
  