require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])
require 'mongo/util/ordered_hash'

describe Rackamole::Store::Log do
  
  describe "#mole" do
    before( :each ) do
      @store = Rackamole::Store::Mongo.new( :host => 'localhost', :port => 27017, :database => 'test_mole_mdb' )
      @store.reset!
      
      @args = OrderedHash.new
      @args[:app_name]     = "Test app"
      @args[:environment]  = :test
      @args[:perf_issue]   = false
      @args[:ip]           = "1.1.1.1"
      @args[:browser]      = "Ibrowse"
      @args[:user_id]      = 100
      @args[:user_name]    = "Fernand"
      @args[:request_time] = 1.0
      @args[:url]          = "http://test_me/"
      @args[:path]         = "/fred"
      @args[:method]       = 'GET'
      @args[:params]       = { :blee => "duh".to_json }
      @args[:session]      = { :fred => 10.to_json }
    end
    
    it "should mole a feature correctly" do
      @store.mole( @args )      
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one( {} )
      feature.should_not be_nil
      feature['app_name'].should       == 'Test app'
      feature['context'].should        == '/fred'
      feature['created_at'].should_not be_nil
      feature['updated_at'].should_not be_nil
     
      log = @store.logs.find_one( {} )
      log.should_not be_nil
      log['params'].should         == { 'blee' => 'duh'.to_json }
      log['ip'].should             == '1.1.1.1'
      log['browser'].should        == 'Ibrowse'
      log['environment'].should    == :test
      log['path'].should           == '/fred'       
      log['url'].should            == 'http://test_me/'
      log['method'].should         == 'GET'
      log['session'].should        == { 'fred' => '10' }
      log['user_name'].should      == 'Fernand'
      log['user_id'].should        == 100
      log['request_time'].should   == 1.0       
      log['perf_issue'].should     == false
      log['created_at'].should_not be_nil
      log['updated_at'].should_not be_nil                   
      @store.connection.dereference( log['feature'] )['app_name'].should == 'Test app'
    end
    
    it "should mole a rails feature correctly" do
      @args[:path]       = '/fred/blee/duh'
      @args[:route_info] = { :controller => 'fred', :action => 'blee', :id => 'duh' }
      @store.mole( @args )
      
      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one( {} )
      feature.should_not be_nil      
      feature['controller'].should == 'fred'
      feature['action'].should     == 'blee'
      feature['context'].should    be_nil 
      
      log = @store.logs.find_one( {} )
      log.should_not be_nil
      log['route_info'].should_not be_nil
    end
    
    it "should reuse an existing feature" do
      @store.mole( @args )
      @store.mole( @args )

      @store.features.count.should == 1
      @store.logs.count.should     == 2
    end

    it "should mole perf correctly" do
      @args[:perf_issue] = true
      @store.mole( @args )

      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one( {} )
      feature.should_not be_nil      

      log = @store.logs.find_one( {} )
      log.should_not be_nil
      log['perf_issue'].should == true
    end
    
    it 'should mole an exception correctly' do
      @args[:exception] = ['fred']
      @store.mole( @args )

      @store.features.count.should == 1
      @store.logs.count.should     == 1
      
      feature = @store.features.find_one( {} )
      feature.should_not be_nil      

      log = @store.logs.find_one( {} )
      log.should_not be_nil
      log['exception'].should == ['fred']      
    end
    
    it 'should keep count an similar exceptions or perf issues' do
      pending "NYI"
    end
  end
  
end
