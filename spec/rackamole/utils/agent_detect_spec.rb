require File.join(File.dirname(__FILE__), %w[.. .. spec_helper] )

describe Rackamole::Utils::AgentDetect do
  
  describe "os" do
    it "should detect the os and version correctly" do
      agents = [ 
        "Opera/8.65 (X11; Linux i686; U; ru)",
        "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1) Opera 8.65 [en]",
        "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.9.0.7) Gecko/2009021910 Firefox/1.5.0.12 (.NET CLR 3.5.30729)",          
        "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.6) Gecko/2009011912 Firefox/1.5.0.12 Ubiquity/0.1.5",
        "Mozilla/5.0 (X11; U; Linux i686 (x86_64); en-US; rv:1.8.0.12) Gecko/20080326 CentOS/1.5.0.12-14.el5.centos Firefox/1.5.0.12",
        "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US) AppleWebKit/532.0 (KHTML, like Gecko) Chrome/3.0.195.24 Safari/532.0",
        "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_6; en-US) AppleWebKit/532.0 (KHTML, like Gecko) Chrome/3.0.195.24 Safari/532.0",
        "Mozilla/5.0 (iPod; U; CPU like Mac OS X; fr) AppleWebKit/420.1 (KHTML, like Gecko) Version/3.0 Mobile/4A102 Safari/522.12",
        "Mozilla/5.0 (iPhone; U; CPU like Mac OS X; en) AppleWebKit/420.1 (KHTML, like Gecko) Version/3.0 Mobile/3B48b Safari/522.12",
        "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR 3.0.4506.2152; .NET CLR 3.5.30729)",
        "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1; SV1; CPT-IE401SP1; .NET CLR 1.0.3705; .NET CLR 1.1.4322; InfoPath.1; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30)",
        "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 2.0.50727; .NET CLR 3.0.04506.30; .NET CLR 1.1.4322; InfoPath.2)",
        "Mozilla/4.0 (compatible; MSIE 5.00; Windows 98)"        
      ]
      expectations = [
        { 
          :browser => { :name => "Opera", :version => "8.65" }, 
          :machine => { :platform => "X11", :os => "Linux", :version => "i686", :local => "N/A" } 
        },
        { 
          :browser => { :name => "Opera", :version => "8.65" }, 
          :machine => { :platform => "compatible", :os => "Windows NT", :version => "5.1", :local => "N/A" } 
        },
        { 
          :browser => { :name => "Firefox", :version => "1.5.0.12" }, 
          :machine => { :platform => "Windows", :os => "Windows NT", :version => "6.0", :local => "en-US" } 
        },
        { 
          :browser => { :name => "Firefox", :version => "1.5.0.12" }, 
          :machine => { :platform => "Macintosh", :os => "Intel Mac OS X", :version => "10.5", :local => "en-US" } 
        },
        { 
          :browser => { :name => "Firefox", :version => "1.5.0.12" }, 
          :machine => { :platform => "X11", :os => "Linux", :version => "i686", :local => "en-US" } 
        },
        { 
          :browser => { :name => "Chrome", :version => "3.0.195.24" }, 
          :machine => { :platform => "Windows", :os => "Windows NT", :version => "5.1", :local => "en-US" } 
        },
        { 
          :browser => { :name => "Chrome", :version => "3.0.195.24" }, 
          :machine => { :platform => "Macintosh", :os => "Intel Mac OS X", :version => "10_5_6", :local => "en-US" } 
        },
        { 
          :browser => { :name => "Safari", :version => "522.12" }, 
          :machine => { :platform => "iPod", :os => "CPU like Mac OS", :version => "X", :local => "fr" } 
        },
        { 
          :browser => { :name => "Safari", :version => "522.12" }, 
          :machine => { :platform => "iPhone", :os => "CPU like Mac OS", :version => "X", :local => "en" } 
        },
        { 
          :browser => { :name => "MSIE", :version => "8.0" }, 
          :machine => { :platform => "compatible", :os => "Windows NT", :version => "5.1", :local => "N/A" } 
        },
        { 
          :browser => { :name => "MSIE", :version => "7.0" }, 
          :machine => { :platform => "compatible", :os => "Windows NT", :version => "5.1", :local => "N/A" } 
        },
        { 
          :browser => { :name => "MSIE", :version => "6.0" }, 
          :machine => { :platform => "compatible", :os => "Windows NT", :version => "5.1", :local => "N/A" } 
        },
        { 
          :browser => { :name => "MSIE", :version => "5.00" }, 
          :machine => { :platform => "compatible", :os => "Windows", :version => "98", :local => "N/A" } 
        }
      ] 
      count = 0
      agents.each do |agent|
        info = Rackamole::Utils::AgentDetect.parse( agent )
        expected = expectations[count]        
        info.should_not be_nil
        %w(name version).each        { |t| info[:browser][t.to_sym].should == expected[:browser][t.to_sym] }
        %w(platform os version).each { |t| info[:machine][t.to_sym].should == expected[:machine][t.to_sym] }
        count += 1
      end      
    end
  end
  
  describe "failure" do
    it "should not crap out if the user agent is not parsable" do
      info = Rackamole::Utils::AgentDetect.parse( "Firefox" )
      %w(browser machine).each { |k| info[k.to_sym].each_pair { |i,v| v.should == (i == :name ? "Firefox" : "N/A") } }
    end
    
    it "should produce an empty info object if nothing can be detected" do
      agents = [ 
        "Oper/8.65 (X11 Linux i686 U ru)",
      ]
      agents.each do |agent|
        info = Rackamole::Utils::AgentDetect.parse( agent )    
        info.should_not be_nil
        %w(browser machine).each { |k| info[k.to_sym].each_pair { |i,v| v.should == "N/A" } }
      end
    end
  end  
end
