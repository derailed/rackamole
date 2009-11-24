require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])

describe Rackamole::Alert::Twitt do
  before( :each ) do
    @alert = Rackamole::Alert::Twitt.new( 'fernand', "blee" )
  end
  
  it "should truncate a message correctly" do
    @alert.send( :truncate, "a"*141 ).should == "a"*137 + '...'
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
      @args[:type]      = Rackamole.feature
      @args[:app_name]  = 'Test'
      @args[:host]      = 'Fred'
      @args[:user_name] = 'Fernand'
      @args[:path]      = '/blee/fred'
    end
    
    it "should twitt a feature alert correctly" do
      client = stub( Twitter::Client )

      @alert.should_receive( :twitt ).once.and_return( client )
      # client.should_receive( :new ).exactly(1).with( 'fernand', 'blee' )
      client.should_receive( :status ).once
    
      @alert.send_alert( @args ).should == "[Feature] Test on Fred - Fernand\n/blee/fred"
    end
  
    it "should twitt a perf alert correctly" do
      @args[:type]         = Rackamole.perf
      @args[:request_time] = 10.0
      
      client = stub( Twitter::Client )
    
      @alert.should_receive( :twitt ).once.and_return( client )
      client.should_receive( :status ).once
    
      @alert.send_alert( @args ).should == "[Perf] Test on Fred - Fernand\n/blee/fred\n10.0 secs"
    end

    it "should twitt a perf alert correctly" do
      @args[:type]  = Rackamole.fault
      @args[:fault] = 'Oh snap!'
      
      client = stub( Twitter::Client )
    
      @alert.should_receive( :twitt ).once.and_return( client )
      client.should_receive( :status ).once
    
      @alert.send_alert( @args ).should == "[Fault] Test on Fred - Fernand\n/blee/fred\nOh snap!"
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