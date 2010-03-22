require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])
require 'chronic'

describe Rackamole::Alert::Growl do
  before( :each ) do
    @recipients = [ {:ip => '1.1.1.1', :password => 'blee' } ]
    @alert = Rackamole::Alert::Growl.new( nil, :growl => { :to => @recipients } )
  end
    
  describe '#display_feature' do
    it "should display a rails feature correctly" do
      @alert.send( :display_feature, :route_info => { :controller => 'fred', :action => 'blee'} ).should == "fred#blee"
    end
    
    it "should display a path feature for other rack framword" do
      @alert.send( :display_feature, :path => '/fred/blee' ).should == "/fred/blee"
    end
  end
  
  describe '#send_alert' do
    before( :each ) do      
      @args = OrderedHash.new
      @args[:type]       = Rackamole.feature
      @args[:app_name]   = 'Test'
      @args[:host]       = 'Fred'
      @args[:user_name]  = 'Fernand'
      @args[:path]       = '/blee/fred'
      @args[:created_at] = Chronic.parse( "2009/11/19" )
    end

    it "should growl a feature alert using class method correctly" do
      growl  = mock( Rackamole::Alert::Growl )
      client = Growl.stub!( :new )
      
      Rackamole::Alert::Growl.should_receive( :new ).with( nil, @recipients ).once.and_return( growl )
      growl.should_receive( :send_alert ).with( @args ).once.and_return( "yeah" )      
      
      Rackamole::Alert::Growl.deliver_alert( nil, { :growl => { :to => @recipients } }, @args )
    end
    
    it "should growl a feature alert correctly" do
      client = stub( Growl )

      @alert.should_receive( :growl ).once.and_return( client )
      client.should_receive( :notify ).once
    
      @alert.send_alert( @args )
    end
  
    it "should growl a perf alert correctly" do
      @args[:type]         = Rackamole.perf
      @args[:request_time] = 10.0
      
      client = stub( Growl )
    
      @alert.should_receive( :growl ).once.and_return( client )
      client.should_receive( :notify ).once
    
      @alert.send_alert( @args )
    end

    it "should twitt a perf alert correctly" do
      @args[:type]  = Rackamole.fault
      @args[:fault] = 'Oh snap!'
      
      client = stub( Growl )
    
      @alert.should_receive( :growl ).once.and_return( client )
      client.should_receive( :notify ).once
    
      @alert.send_alert( @args )
    end
  end

  describe "#format_time" do
    it "should format a request time correctly" do
      @alert.send( :format_time, 12.1234455 ).should == 12.12
    end
  end
  
  describe "#format_host" do
    it "should format a host with domain name correctly" do
      @alert.send( :format_host, 'blee@acme.com' ).should == 'blee'
    end
    
    it "should deal with ip host" do
      @alert.send( :format_host, '1.1.1.1' ).should == '1.1.1.1'
    end

    it "should deal with aliases" do
      @alert.send( :format_host, 'fred' ).should == 'fred'
    end
  end
  
end