require File.expand_path(File.join(File.dirname(__FILE__), %w[spec_helper]))

describe Rackamole do
 before( :all ) do        
    @root = ::File.expand_path( ::File.join(::File.dirname(__FILE__), ".." ) )
  end
    
  it "is versioned" do
    Rackamole.version.should =~ /\d+\.\d+\.\d+/
  end
  
  it "generates a correct path relative to root" do
    Rackamole.path( "mole.rb" ).should == ::File.join(@root, "mole.rb" )
  end
  
  it "generates a correct path relative to lib" do
    Rackamole.libpath(%w[ rackmole mole.rb]).should == ::File.join(@root, "lib", "rackmole", "mole.rb")
  end       
  
end