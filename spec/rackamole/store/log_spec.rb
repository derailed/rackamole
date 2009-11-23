require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])

describe Rackamole::Store::Log do  
  describe "#mole" do
    before( :each ) do
      @test_file = '/tmp/test_mole.log'
      File.delete( @test_file ) if File.exists?( @test_file )

      @store = Rackamole::Store::Log.new( @test_file )
        
      @args = OrderedHash.new
      @args[:type]         = Rackamole.feature
      @args[:app_name]     = "Test app"
      @args[:environment]  = :test
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
      results = File.read( @test_file ).gsub( /.* Mole \:\s/, '' )      
      expected = File.read( File.join( File.dirname(__FILE__), %w[.. .. expected_results mole_feature.log] ) )    
      expected.should == results      
    end

    it "should mole an exception correctly" do
      @args[:type]         = Rackamole.fault
      @args[:fault]        = "Shiet"      
      @args[:stack]        = [ 'Oh snap!' ]
      @args[:ruby_version] = 'ruby 1.8.6 (2007-03-13 patchlevel 0) [i686-darwin8.10.1]'

      @store.mole( @args )
      results = File.read( @test_file ).gsub( /.* Mole \:\s/, '' )
      expected = File.read( File.join( File.dirname(__FILE__), %w[.. .. expected_results mole_exception.log] ) )    
      expected.should == results      
    end
    
    it "should mole a performance issue correctly" do
      @args[:type] = Rackamole.perf
      @store.mole( @args )
      results = File.read( @test_file ).gsub( /.* Mole \:\s/, '' )
      expected = File.read( File.join( File.dirname(__FILE__), %w[.. .. expected_results mole_perf.log] ) )    
      expected.should == results      
    end
  end    
    
end
