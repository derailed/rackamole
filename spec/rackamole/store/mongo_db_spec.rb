require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])
require 'chronic'

describe Rackamole::Store::MongoDb do
  
  describe "#mole" do
    
    before( :all ) do
      @now   = Chronic.parse( "11/27/2009" )
      @store = Rackamole::Store::MongoDb.new( 
        :host     => 'localhost', 
        :port     => 27017, 
        :db_name  => 'mole_app_test_mdb',
        :logger   => Rackamole::Logger.new( :file_name => $stdout, :log_level => 'info' ) )
      @db    = @store.database
    end
    
    before( :each ) do
      @store.send( :reset! )
      
      @args = OrderedHash.new
      @args[:type]               = Rackamole.feature
      @args[:app_name]           = "app"
      @args[:environment]        = :test
      @args[:perf_issue]         = false
      @args[:ip]                 = "1.1.1.1"
      @args[:browser]            = OrderedHash.new
      @args[:browser][:name]     = "Ibrowse"
      @args[:browser][:version]  = "1.X"
      @args[:machine]            = OrderedHash.new
      @args[:machine][:platform] = "Blee"
      @args[:machine][:os]       = "Windoze"
      @args[:machine][:version]  = "10.0"
      @args[:user_id]            = 100
      @args[:user_name]          = "Fernand"
      @args[:request_time]       = 1.0
      @args[:url]                = "http://test_me/"
      @args[:path]               = "/fred"
      @args[:method]             = 'GET'
      @args[:params]             = { :blee => "duh".to_json }
      @args[:session]            = { :fred => 10.to_json }
      @args[:created_at]         = @now.utc
    end
        
    it "should mole a context based feature correctly" do
      @store.mole( @args )
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one()
      feature.should_not be_nil
      feature['app'].should     == 'app'
      feature['env'].should     == 'test'
      feature['ctx'].should     == '/fred'
     
      log = @store.logs.find_one()
      log.should_not                be_nil
      log['typ'].should             == Rackamole.feature  
      log['fid'].should_not         be_nil
      log['par'].should             == { 'blee' => 'duh'.to_json }
      log['ip'].should              == '1.1.1.1'
      log['bro']['name'].should     == "Ibrowse"
      log['bro']['version'].should  == "1.X"
      log['mac']['platform'].should == "Blee"
      log['mac']['os'].should       == "Windoze"
      log['mac']['version'].should  == "10.0"
      log['url'].should             == 'http://test_me/'
      log['met'].should             == 'GET'
      log['ses'].should             == { 'fred' => '10' }
      log['uid'].should_not         be_nil
      log['rti'].should             == 1.0
      log['did'].should             == '20091127'
      log['tid'].should             == '190000'

      feature = @store.features.find_one( log['fid'] )
      feature.should_not     be_nil
      feature['app'].should  == 'app'
      feature['env'].should  == 'test'
      feature['ctx'].should  == '/fred'
      feature['did'].should  == '20091127'
            
      user = @store.users.find_one( log['uid'] )
      user.should_not be_nil
      user['una'].should == "Fernand"
      user['uid'].should == 100
      user['did'].should == '20091127'
    end
    
    it "should convert a.b.c session keys correctly" do
      @args[:session] = { 'a.b.c' => 10 }
      
      @store.mole( @args )
      @store.features.count.should == 1
      @store.logs.count.should     == 1

      log = @store.logs.find_one()
      log.should_not        be_nil
      log['ses'].should     == { 'a_b_c' => 10 }      
    end
    
    it "should mole a rails feature correctly" do
      @args[:path]       = '/fred/blee/duh'
      @args[:route_info] = { :controller => 'fred', :action => 'blee', :id => 'duh' }
      @store.mole( @args )
      
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one()
      feature.should_not be_nil      
      feature['ctl'].should == 'fred'
      feature['act'].should == 'blee'
      feature['ctx'].should be_nil 
      
      log = @store.logs.find_one()      
      log.should_not be_nil
      log['typ'].should == Rackamole.feature
      log['pat'].should_not be_nil
    end
    
    it "should reuse an existing feature" do
      @store.mole( @args )
      @store.mole( @args )

      @store.features.count.should == 1
      @store.logs.count.should     == 2
    end
  
    it "should mole perf correctly" do
      @args[:type]         = Rackamole.perf
      @store.mole( @args )
  
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one()
      feature.should_not be_nil      
  
      log = @store.logs.find_one()
      log.should_not be_nil
      log['typ'].should == Rackamole.perf
    end
    
    it 'should mole an exception correctly' do
      @args[:type]  = Rackamole.fault
      @args[:stack] = ['fred']
      @args[:fault] = "Oh Snap!"
      @store.mole( @args )
  
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one()
      feature.should_not be_nil
  
      log = @store.logs.find_one()
      log.should_not be_nil      
      log['typ'].should == Rackamole.fault
      log['sta'].should == ['fred']
      log['msg'].should == 'Oh Snap!'      
    end
    
    it 'should keep count an similar exceptions or perf issues' do
      pending "NYI"
    end
  end
  
  describe( "authentication" ) do
    it "should authenticate correctly if a store is setup with auth" do
      store = Rackamole::Store::MongoDb.new( 
        :host     => 'localhost', 
        :port     => 27017, 
        :db_name  => 'mole_sec_app_test_mdb',
        :username => 'fred',
        :password => 'letmein',
        :logger   => Rackamole::Logger.new( :file_name => $stdout, :log_level => 'info' ) )
    end
    
    it "should crap out if auth failed" do
      lambda {
        store = Rackamole::Store::MongoDb.new( 
          :host     => 'localhost', 
          :port     => 27017, 
          :db_name  => 'mole_sec_app_test_mdb',
          :username => 'fred',
          :password => 'hoy',
          :logger   => Rackamole::Logger.new( :file_name => $stdout, :log_level => 'info' ) )      
      }.should raise_error( /Failed to authenticate user 'fred'/ )
    end
  end
end