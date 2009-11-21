require File.join(File.dirname(__FILE__), %w[.. spec_helper])
# require 'actionpack'

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
        :user_key       => { :session_key => :user_id, :extractor => lambda{ |k| "Test user #{k}"} },
        :store          => @test_store )
    end
    
    it "should set the mole meta correctly" do
      get "/", nil, @test_env
      @test_store.mole_result[:app_name].should    == "Test App"
      @test_store.mole_result[:environment].should == :test
      @test_store.mole_result[:user_id].should     == 100
      @test_store.mole_result[:user_name].should   == 'Test user 100'
      @test_store.mole_result[:ip].should          == '1.1.1.1'
      @test_store.mole_result[:browser].should     == 'Firefox'
      @test_store.mole_result[:method].should      == 'GET'
      @test_store.mole_result[:url].should         == 'http://example.org/'
      @test_store.mole_result[:path].should        == '/'
      @test_store.mole_result[:performance].should == false
      @test_store.mole_result[:params].should      be_nil
      @test_store.mole_result[:session].should_not be_nil
      @test_store.mole_result[:session].should    == { :user_id => '100' }
    end
    
    it "mole an exception correctly" do
      begin
        raise 'Oh snap!'
      rescue => boom
        get "/", nil, @test_env.merge( { 'mole.exception' => boom } )
        @test_store.mole_result[:stack].should have(4).items
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
