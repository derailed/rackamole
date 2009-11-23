require File.join(File.dirname(__FILE__), %w[.. spec_helper])

describe Rack::Mole do
  include Rack::Test::Methods
    
  before :each do
    @response = [ 200, {"Content-Type" => "text/plain"}, ["success"] ]
    @test_env = { 'rack.session' => { :user_id => 100 }, 'HTTP_X_FORWARDED_FOR' => '1.1.1.1', 'HTTP_USER_AGENT' => "Firefox" }    
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

  it "should mole a framwework exception correctly" do
    @test_store = TestStore.new
    error_app( 
      :app_name       => "Test App", 
      :environment    => :test,
      :perf_threshold => 0.1,
      :user_key       => { :session_key => :user_id, :extractor => lambda{ |k| "Test user #{k}"} },
      :store          => @test_store )
    
    begin
      get "/", nil, @test_env
    rescue 
      @test_store.mole_result[:stack].should have(4).items      
    end
  end
    
  describe 'moling a request' do
    before :each do
      @test_store = TestStore.new
      app( 
        :app_name       => "Test App", 
        :environment    => :test,
        :perf_threshold => 0.1,        
        :user_key       => { :session_key => :user_id, :extractor => lambda{ |k| "Fernand (#{k})"} },
        :store          => @test_store )
    end
    
    it "should set the mole meta correctly" do
      get "/fred/blee", nil, @test_env
      @test_store.mole_result[:app_name].should    == "Test App"
      @test_store.mole_result[:environment].should == :test
      @test_store.mole_result[:user_id].should     == 100
      @test_store.mole_result[:user_name].should   == 'Fernand (100)'
      @test_store.mole_result[:ip].should          == '1.1.1.1'
      @test_store.mole_result[:browser].should     == 'Firefox'
      @test_store.mole_result[:method].should      == 'GET'
      @test_store.mole_result[:url].should         == 'http://example.org/fred/blee'
      @test_store.mole_result[:path].should        == '/fred/blee'
      @test_store.mole_result[:type].should        == Rackamole.feature
      @test_store.mole_result[:params].should      be_nil
      @test_store.mole_result[:session].should_not be_nil
      @test_store.mole_result[:session].should    == { :user_id => '100' }
    end
    
    it "mole an exception correctly" do
      begin
        raise 'Oh snap!'
      rescue => boom
        get "/crap/out", nil, @test_env.merge( { 'mole.exception' => boom } )
        @test_store.mole_result[:type].should  == Rackamole.fault
        @test_store.mole_result[:stack].should have(4).items
        @test_store.mole_result[:fault].should == 'Oh snap!'        
      end
    end
        
    it "should capture request parameters correctly" do
        get "/", { :blee => 'duh' }, @test_env
        @test_store.mole_result[:params].should == { :blee => "duh".to_json }
    end
  end
      
  describe 'username in session' do
    before :each do
      @test_store = TestStore.new
      app( 
        :app_name       => "Test App", 
        :environment    => :test,
        :perf_threshold => 0.1,
        :user_key       => :user_name,
        :store          => @test_store )
    end
    
    it "should pickup the user name from the session correctly" do
      get "/", nil, @test_env.merge( { 'rack.session' => { :user_name => "Fernand" } } )
      @test_store.mole_result[:user_id].should   be_nil
      @test_store.mole_result[:user_name].should == 'Fernand'
    end
  end
  
  describe '#alertable?' do
    before( :each ) do
      @filter = { :enabled => true, :features => [Rackamole.perf, Rackamole.fault] }
      @rack = Rack::Mole.new( nil )
    end
    
    it "should return true if a feature can be twitted on" do
      @rack.send( :alertable?, @filter, Rackamole.perf ).should == true
    end
    
    it "should fail if the type is not in range" do
      @rack.send( :alertable?, @filter, 10 ).should == false
    end
    
    it "should fail if this is not an included feature" do
      @rack.send( :alertable?, @filter, Rackamole.feature ).should == false
    end
    
    it "should always return false if the alert is disabled" do
      @filter[:enabled] = false
      @rack.send( :alertable?, @filter, Rackamole.perf ).should == false
    end
    
    it "should fail if the alert is not configured" do
      @rack.send( :alertable?, nil, Rackamole.perf ).should == false
    end    
  end

  describe '#configured?' do
    before( :each ) do
      options = {
        :twitter_auth => { :username => 'Fernand', :password => "Blee" },
        :twitt_on     => { :enabled => true, :features => [Rackamole.perf, Rackamole.fault] }
      }
      @rack = Rack::Mole.new( nil, options )
    end
    
    it "should return true if an option is correctly configured" do
      @rack.send( :configured?, :twitter_auth, [:username, :password] ).should == true
      @rack.send( :configured?, :twitt_on, [:enabled, :features] ).should == true
    end
    
    it "should fail is an option is not set" do
      @rack.send( :configured?, :twitter, [:username, :password] ).should == false
    end
    
    it "should fail is an option is not correctly configured" do
      @rack.send( :configured?, :twitter_auth, [:username, :pwd] ).should == false
    end    
  end
  
  describe '#id_browser' do
    before :all do
      @rack = Rack::Mole.new( nil )
    end
    
    it "should detect a browser type correctly" do
      browser = @rack.send( :id_browser, "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 3.0.04506.648; InfoPath.2; MS-RTC LM 8; SPC 3.1 P1 Ta)")
      browser.should == 'MSIE 7.0'
    end
    
    it "should return unknow if can't detect it" do
      @rack.send( :id_browser, 'IBrowse' ).should == 'N/A'
    end
  end
end
