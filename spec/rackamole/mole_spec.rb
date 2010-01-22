require File.join(File.dirname(__FILE__), %w[.. spec_helper])
require 'action_controller'

describe Rack::Mole do
  include Rack::Test::Methods
    
  before :each do
    @response   = [ 200, {"Content-Type" => "text/plain"}, ["success"] ]
    @test_store = TestStore.new    
    @test_env   = { 
      'rack.session'         => { :user_id => 100, :username => "fernand" }, 
      'HTTP_X_FORWARDED_FOR' => '1.1.1.1', 
      'HTTP_USER_AGENT'      => "Firefox" 
    }
    @opts       = {
      :app_name       => "Test App", 
      :environment    => :test,
      :excluded_paths => ['/should_bail'],      
      :perf_threshold => 0.1,
      :user_key       => :username,
      :store          => @test_store
    }
  end
      
  class TestStore
    attr_accessor :mole_result    
    def mole( args )
      @mole_result = args
    end
  end
  
  def app( opts={} )
    response = @response
    @app ||= Rack::Builder.new do
      use Rack::Lint
      use Rack::Mole, opts
      run lambda { |env| response }
    end
  end

  def error_app( opts={} )
    @app ||= Rack::Builder.new do
      use Rack::Lint
      use Rack::Mole, opts
      run lambda { |env| raise "Oh Snap!" }
    end
  end

  def slow_app( opts={} )
    response = @response
    @app ||= Rack::Builder.new do
      use Rack::Lint
      use Rack::Mole, opts
      run lambda { |env| sleep(0.2); response }
    end
  end

  # ---------------------------------------------------------------------------
  describe "fault duplicate" do 
    before( :each ) do
      error_app( @opts )
    end
        
    it "should mole a fault issue correctly" do      
      begin
        get "/", nil, @test_env
      rescue
        last_request.env['mole.stash'].should_not be_nil
        fault = last_request.env['mole.stash'].send( :find_fault, "/", "./spec/rackamole/mole_spec.rb:45:in `error_app'" )
        fault.should_not be_nil
        fault.count.should == 1
      end
    end

    it "should trap a recuring fault on given path correctly" do
      env = @test_env
      2.times do |i|
        begin
          get "/", nil, env
        rescue
          last_request.env['mole.stash'].should_not be_nil
          fault = last_request.env['mole.stash'].send( :find_fault, "/", "./spec/rackamole/mole_spec.rb:45:in `error_app'" )
          fault.should_not be_nil
          fault.count.should == i+1
          env = last_request.env
        end
      end
    end

    it "should trap a recuring fault on different path correctly" do    
      env = @test_env
      2.times do |i|
        begin        
          env['PATH_INFO'] = "/#{i}"
          get "/#{i}", nil, env
        rescue => boom
          last_request.env['mole.stash'].should_not be_nil
          fault = last_request.env['mole.stash'].send( :find_fault, "/", "./spec/rackamole/mole_spec.rb:45:in `error_app'" )          
          fault.should_not be_nil
          fault.count.should == i+1
          env = last_request.env
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  describe "performance duplicate" do 
    before( :each ) do
      @test_store = TestStore.new
      slow_app( @opts )
    end
    
    it "should mole a perf issue correctly" do    
      get "/", nil, @test_env
      last_request.env['mole.stash'].should_not be_nil    
      perf = last_request.env['mole.stash'].send( :find_perf, "/" )
      perf.should_not be_nil
      perf.count.should == 1
    end

    it "should trap a recuring perf on given path correctly" do
      env = @test_env
      2.times do |i| 
        get "/", nil, env
        perf = last_request.env['mole.stash'].send( :find_perf, "/" )
        perf.should_not be_nil
        perf.count.should == i+1
        env = last_request.env
      end
    end

    it "should trap a recuring perf on different path correctly" do    
      env = @test_env
      2.times do |i|
        env['PATH_INFO'] = "/#{i}"
        get "/#{i}", nil, env
        last_request.env['mole.stash'].should_not be_nil
        count = 0
        while count <= i
          perf = last_request.env['mole.stash'].send( :find_perf, "/#{count}" )
          perf.should_not be_nil
          perf.count.should == 1
          count += 1
        end
        env = last_request.env
      end
    end
  end
  
  # ---------------------------------------------------------------------------  
  it "should mole a framwework exception correctly" do
    error_app( @opts )    
    begin
      get "/", nil, @test_env
    rescue 
      @test_store.mole_result[:stack].should have(4).items
      last_request.env['mole.stash'].should_not be_nil
      fault = last_request.env['mole.stash'].send( :find_fault, "/", "./spec/rackamole/mole_spec.rb:45:in `error_app'" )
      fault.should_not be_nil
      fault.count.should == 1
    end
  end
        
  # ---------------------------------------------------------------------------
  describe "exclusions" do    
    before( :each)  do
      opts = @opts.clone
      opts[:mole_excludes] = [:headers, :body, :browser, :ip, :url]      
      app( opts )
    end
    
    it "should exclude some mole attributes correctly" do      
      get "/fred/blee", nil, @test_env
      
      @test_store.mole_result[:app_name].should     == "Test App"
      @test_store.mole_result[:environment].should  == :test
      @test_store.mole_result[:user_id].should      be_nil
      @test_store.mole_result[:user_name].should    == 'fernand'
      @test_store.mole_result[:method].should       == 'GET'
      @test_store.mole_result[:path].should         == '/fred/blee'
      @test_store.mole_result[:type].should         == Rackamole.feature
      @test_store.mole_result[:params].should       be_nil
      @test_store.mole_result[:session].should_not  be_nil
      @test_store.mole_result[:session].keys.should have(2).items
      @test_store.mole_result[:status].should       == 200
      
      # Excluded
      @test_store.mole_result[:headers].should      be_nil
      @test_store.mole_result[:body].should         be_nil      
      @test_store.mole_result[:browser].should      be_nil      
      @test_store.mole_result[:ip].should           be_nil  
      @test_store.mole_result[:url].should          be_nil          
    end
  end
        
  # ---------------------------------------------------------------------------    
  describe 'moling a request' do
    before :each do
      app( @opts )
    end
    
    it "should set the mole meta correctly" do
      get "/fred/blee", nil, @test_env
      
      @test_store.mole_result[:app_name].should     == "Test App"
      @test_store.mole_result[:environment].should  == :test
      @test_store.mole_result[:user_id].should      be_nil
      @test_store.mole_result[:user_name].should    == 'fernand'
      @test_store.mole_result[:ip].should           == '1.1.1.1'
      @test_store.mole_result[:browser].should      == 'Firefox'
      @test_store.mole_result[:method].should       == 'GET'
      @test_store.mole_result[:url].should          == 'http://example.org/fred/blee'
      @test_store.mole_result[:path].should         == '/fred/blee'
      @test_store.mole_result[:type].should         == Rackamole.feature
      @test_store.mole_result[:params].should       be_nil
      @test_store.mole_result[:session].should_not  be_nil
      @test_store.mole_result[:session].keys.should have(2).items
      @test_store.mole_result[:status].should       == 200
      @test_store.mole_result[:headers].should      == { "Content-Type" => "text/plain" }
      @test_store.mole_result[:body].should         be_nil
    end
    
    it "mole an exception correctly" do
      begin
        raise 'Oh snap!'
      rescue => boom
        @test_env['mole.exception'] = boom
        get "/crap/out", nil, @test_env
        @test_store.mole_result[:type].should  == Rackamole.fault
        @test_store.mole_result[:stack].should have(4).items
        @test_store.mole_result[:fault].should == 'Oh snap!'
        last_request.env['mole.stash'].should_not be_nil
        fault = last_request.env['mole.stash'].send( :find_fault, "/", "./spec/rackamole/mole_spec.rb:226" )
        fault.should_not be_nil
        fault.count.should == 1
      end
    end
        
    it "should capture request parameters correctly" do
        get "/", { :blee => 'duh' }, @test_env
        @test_store.mole_result[:params].should == { :blee => "duh".to_json }
    end
    
    it "should not mole an exclusion" do
      get '/should_bail', nil, @test_env      
      @test_store.mole_result.should be_nil
    end
  end
      
  # ---------------------------------------------------------------------------      
  describe 'username in session' do
    it "should pickup the user name from the session correctly" do
      app( @opts )
      get "/", nil, @test_env      
      @test_store.mole_result[:user_id].should   be_nil
      @test_store.mole_result[:user_name].should == 'fernand'
    end
    
    it "should extract a username correctly" do
      @opts[:user_key] = { :session_key => :user_id, :extractor => lambda { |k| "Fernand #{k}" } }    
      app( @opts )    
      get "/", nil, @test_env
      @test_store.mole_result[:user_id].should   == 100
      @test_store.mole_result[:user_name].should == 'Fernand 100'
    end      
  end

  describe "rails env" do
    it "should find route info correctly" do
      RAILS_ENV = true
      ActionController::Routing::Routes.stub!( :recognize_path ).and_return( { :controller => 'fred', :action => 'blee' } )
      rack = Rack::Mole.new( nil, :app_name => "test app" )
      
      # routes.should_receive( 'recognize_path' ).with( 'fred', { :method => 'blee' } ).and_return(  )
      res = rack.send( :get_route, OpenStruct.new( :path => "/", :request_method => "GET") )
      res.should_not          be_nil
      res[:controller].should == 'fred'
      res[:action].should     == 'blee'
    end
  end
  
  # ---------------------------------------------------------------------------      
  describe 'sending alerts' do
    it "should send out alerts on the first occurrance of a perf issue" do
      Rackamole::Alert::Twitt.stub!( :deliver_alert )
      Rackamole::Alert::Emole.stub!( :deliver_alert )

      @opts[:twitter] = { :username => "fred", :password => "blee", :alert_on => [Rackamole.perf] }
      @opts[:email]   = { :from => "fred", :to => ["blee"], :alert_on => [Rackamole.perf] }
      
      slow_app( @opts )
      
      Rackamole::Alert::Emole.should_receive( :deliver_alert ).once
      Rackamole::Alert::Twitt.should_receive( :deliver_alert ).once      
      
      get "/", nil, @test_env
    end    
    
    it "should should not send several alerts on an occurance of the same issue" do
      Rackamole::Alert::Twitt.stub!( :deliver_alert )
      Rackamole::Alert::Emole.stub!( :deliver_alert )

      @opts[:twitter] = { :username => "fred", :password => "blee", :alert_on => [Rackamole.perf] }
      @opts[:email]   = { :from => "fred", :to => ["blee"], :alert_on => [Rackamole.perf] }

      slow_app( @opts )
            
      env = @test_env
      # First time ok
      Rackamole::Alert::Emole.should_receive( :deliver_alert ).once
      Rackamole::Alert::Twitt.should_receive( :deliver_alert ).once      
      get "/", nil, env
      env = last_request.env
      # Second time - no alerts
      Rackamole::Alert::Emole.should_not_receive( :deliver_alert )
      Rackamole::Alert::Twitt.should_not_receive( :deliver_alert )
      get "/", nil, env      
    end    
    
  end
  
  # ---------------------------------------------------------------------------  
  describe '#alertable?' do
    before( :each ) do
      @rack = Rack::Mole.new( nil, 
        :app_name => "test app",
        :twitter  => { 
          :username => 'fred', 
          :password => 'blee', 
          :alert_on => [Rackamole.perf, Rackamole.fault] 
        },
        :email    => { 
          :from     => 'fred', 
          :to       => ['blee'], 
          :alert_on => [Rackamole.perf, Rackamole.fault, Rackamole.feature] 
        } )
    end
    
    it "should succeeed if a feature can be twitted on" do
      @rack.send( :alertable?, :twitter, Rackamole.perf ).should == true
    end
    
    it "should fail if the type is not in range" do
      @rack.send( :alertable?, :twitt_on, 10 ).should == false
    end
    
    it "should fail if this is not an included feature" do
      @rack.send( :alertable?, :twitter, Rackamole.feature ).should == false
    end
    
    it "should fail if an alert is not configured" do
      @rack.send( :alertable?, :mail_on, Rackamole.perf ).should == false
    end    
  end

  # ---------------------------------------------------------------------------
  describe '#configured?' do
    before( :each ) do
      options = {
        :app_name     => "test app",
        :blee         => [1,2,3],
        :twitter      => { :username => 'Fernand', :password => "Blee", :alert_on => [Rackamole.perf, Rackamole.fault] },
      }
      @rack = Rack::Mole.new( nil, options )
    end
    
    it "should return true if an option is correctly configured" do
      @rack.send( :configured?, :twitter, [:username, :password] ).should == true
      @rack.send( :configured?, :twitter, [:alert_on] ).should            == true
    end
    
    it "should fail if an option is not set" do
      lambda {      
        @rack.send( :configured?, :twitter, [:username, :password, :blee] )
      }.should raise_error(RuntimeError, /Option \:twitter is not properly configured. Missing \:blee in \[alert_on,password,username\]/)
    end

    it "should fail if an option is not a hash" do
      lambda {
        @rack.send( :configured?, :blee, [:username, :pwd] )
      }.should raise_error(RuntimeError, /Invalid value for option \:blee\. Expecting a hash with symbols \[username,pwd\]/ )
    end
    
    it "should fail if an option is not correctly configured" do
      lambda {
        @rack.send( :configured?, :fred, [:username, :pwd], false )
      }.should raise_error(RuntimeError, /Missing option key \:fred/ )
    end    
  end
  
  # ---------------------------------------------------------------------------
  describe '#id_browser' do
    before :all do
      @rack = Rack::Mole.new( nil, :app_name => "test app" )
    end
    
    it "should detect a browser type correctly" do
      browser = @rack.send( :id_browser, "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; InfoPath.2; MS-RTC LM 8; SPC 3.1 P1 Ta)")
      browser.should == 'MSIE 7.0'
    end
    
    it "should return unknow if can't detect it" do
      @rack.send( :id_browser, 'IBrowse' ).should == 'N/A'
    end
  end
  
  # ---------------------------------------------------------------------------
  describe 'YAML load' do
    before :all do
      @config_file = File.join( File.dirname(__FILE__), %w[.. test_configs rackamole_test.yml] )
    end

    it "should raise an error if the config is hosed" do
      flawed = File.join( File.dirname(__FILE__), %w[.. test_configs flawed_config.yml] )
      lambda{ 
        Rack::Mole.new( nil, :environment => 'test', :config_file => flawed )
      }.should raise_error( RuntimeError, /Unable to parse Rackamole config file/ ) 
    end
        
    it "should load the test env correctly from a yaml file" do
      @rack = Rack::Mole.new( nil, :environment => 'test', :config_file => @config_file )
      @rack.send( 'options' )[:moleable].should == false
    end
    
    it "should load the dev env correctly from a yaml file" do
      @rack = Rack::Mole.new( nil, :environment => 'development', :config_file => @config_file )
      opts  = @rack.send( 'options' )
      opts[:moleable].should       == true
      opts[:app_name].should       == 'TestApp'
      opts[:user_key].should       == :user_name 
      opts[:perf_threshold].should == 2
      
      @rack.send( :alertable?, :twitter, Rackamole.perf ).should  == true
      @rack.send( :alertable?, :twitter, Rackamole.fault ).should == false
      @rack.send( :alertable?, :email, Rackamole.fault ).should   == true
      @rack.send( :alertable?, :email, Rackamole.perf ).should    == false            
    end
    
    it "should load the prod env correctly" do      
      @rack = Rack::Mole.new( nil, :environment => 'production', :config_file => @config_file )
      opts  = @rack.send( 'options' )
      opts[:moleable].should       == true
      opts[:app_name].should       == 'TestApp'
      opts[:perf_threshold].should == 5
      (opts[:store].instance_of?(Rackamole::Store::MongoDb)).should == true
      opts[:store].db_name.should == "mole_fred_production"
      opts[:store].port.should    == 10
      opts[:store].host.should    == "fred"
    end        
  end
  
  # ---------------------------------------------------------------------------    
  describe 'excludes params' do
    
    it "should exclude request params correctly" do
      @opts[:param_excludes] = [:bobo]
      app( @opts )      
      get "/", { :blee => 'duh', :bobo => 10 }, @test_env
      params = @test_store.mole_result[:params]
      params.should_not be_nil
      params[:blee].should == 'duh'.to_json
      params.keys.size.should == 1
      params.has_key?( :bobo ).should == false
    end    
    
    it "should exclude session params correctly" do
      @test_env['rack.session'][:bobo] = 'exclude_me'
      @opts[:session_excludes] = [:bobo]      
      app( @opts )      
      get "/", { :username => 'duh', :bobo => 10 }, @test_env
      params = @test_store.mole_result[:params]
      params.should_not be_nil
      params.keys.size.should == 2
      session = @test_store.mole_result[:session]
      session.should_not be_nil
      session.keys.size.should == 2
      session.has_key?( :bobo ).should == false
    end    
    
  end
  
  # ---------------------------------------------------------------------------    
  describe 'required params' do
    it "should crap out if a required param is omitted" do
      lambda {
        Rack::Mole.new( app )
      }.should raise_error( /app_name/ )
    end
  end

end
