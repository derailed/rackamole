require File.expand_path(File.join(File.dirname(__FILE__), %w[.. .. spec_helper]))

describe Rackamole::Alert::Emole do
  
  before( :each ) do
    @from = "fernand"
    @to   = %w[fernand bobo blee]
    
    Mail.defaults do
      delivery_method :test
    end
    
    @options = { :email => { :from => @from, :to => @to }, :perf_threshold => 10 }
    
    @args = BSON::OrderedHash.new
    @args[:type]         = Rackamole.feature
    @args[:method]       = "POST"
    @args[:status]       = 200
    @args[:app_name]     = 'Test'
    @args[:host]         = 'Fred'
    @args[:user_name]    = 'Fernand'
    @args[:url]          = 'http://bumblebeetuna/fred/blee'
    @args[:path]         = '/fred/blee'
    @args[:software]     = "nginx/0.7.64"
    @args[:request_time] = 0.55
    @args[:ruby_version] = "ruby 1.8.7 (2009-06-12 patchlevel 174) [i686-darwin10.0.0]"

    @args[:params]      = BSON::OrderedHash.new
    @args[:params][:id]   = 10
    @args[:params][:fred] = [10,20,30]
    
    @args[:session] = BSON::OrderedHash.new
    @args[:session][:blee] = "Hello World"
    @args[:session][:fred] = [10,20,30]
    
    @args[:headers] = BSON::OrderedHash.new
    @args[:headers]['Cache-Control']  = "no-cache"
    @args[:headers]['Content-Type']   = "text/html; charset=utf-8"
    @args[:headers]['Content-Length'] = "17911"
    @args[:headers]['Set-Cookie']     = "fred"

    @args[:browser] = BSON::OrderedHash.new
    @args[:browser][:name]    = "Chromey"
    @args[:browser][:version] = "1.12.23.54"
    
    @args[:machine] = BSON::OrderedHash.new
    @args[:machine][:platform] = "Windoze"
    @args[:machine][:os]       = "Windows NT"
    @args[:machine][:version]  = "3.5"
    @args[:machine][:local]    = "en-us"    
    
  end
  
  describe "#alert" do
    
    it "should send a feature email correctly" do
      alert = Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )
      alert.body.to_s.should == feature_body
      alert.subject.should   == "Rackamole <Feature> on Test.Fred for user Fernand"
      alert.from.should      == ["fernand"]
      alert.to.should        == ["fernand", 'bobo', 'blee']
    end

    it "should send a perf email correctly" do
      @args[:type] = Rackamole.perf
      @args[:request_time] = 15.2

      alert = Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )
      alert.body.to_s.should == perf_body
      alert.subject.should   == "Rackamole <Performance> 15.20 on Test.Fred for user Fernand"
      alert.from.should      == ["fernand"]
      alert.to.should        == ["fernand", 'bobo', 'blee']      
    end

    it "should send a fault email correctly" do
      @args[:type]   = Rackamole.fault
      @args[:fault]  = 'Oh Snap!'
      @args[:stack]  = ['fred', 'blee']
      alert = Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )
      alert.body.to_s.should == fault_body
      alert.subject.should   == "Rackamole <Fault> on Test.Fred for user Fernand"
      alert.from.should      == ["fernand"]
      alert.to.should        == ["fernand", 'bobo', 'blee']
    end
  end
  
  def feature_body
msg=<<MSG
Feature alert on application Test on host Fred

----------------------------------------
o What

  user_name: Fernand
  url: http://bumblebeetuna/fred/blee
  path: /fred/blee
  status: 200
  method: POST
  request_time: 0.55
  ip: 

----------------------------------------
o Server

  host: Fred
  software: nginx/0.7.64
  ruby_version: ruby 1.8.7 (2009-06-12 patchlevel 174) [i686-darwin10.0.0]

----------------------------------------
o Params

  id: 10
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Session

  blee: Hello World
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Browser

  name: Chromey
  version: 1.12.23.54

----------------------------------------
o Headers

  Cache-Control: no-cache
  Content-Type: text/html; charset=utf-8
  Content-Length: 17911
  Set-Cookie: fred

----------------------------------------
o Client

  platform: Windoze
  os: Windows NT
  version: 3.5
  local: en-us


===============================================================
Powered by Rackamole. This message was generated automatically.
Please do not respond directly.
MSG
  end
  
  def perf_body
msg=<<MSG
Performance alert on application Test on host Fred

----------------------------------------
o What

  request_time: 15.20 [10]
  user_name: Fernand
  url: http://bumblebeetuna/fred/blee
  path: /fred/blee
  status: 200
  method: POST
  ip: 

----------------------------------------
o Server

  host: Fred
  software: nginx/0.7.64
  ruby_version: ruby 1.8.7 (2009-06-12 patchlevel 174) [i686-darwin10.0.0]

----------------------------------------
o Params

  id: 10
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Session

  blee: Hello World
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Browser

  name: Chromey
  version: 1.12.23.54

----------------------------------------
o Headers

  Cache-Control: no-cache
  Content-Type: text/html; charset=utf-8
  Content-Length: 17911
  Set-Cookie: fred

----------------------------------------
o Client

  platform: Windoze
  os: Windows NT
  version: 3.5
  local: en-us


===============================================================
Powered by Rackamole. This message was generated automatically.
Please do not respond directly.
MSG
  end

  def fault_body
msg=<<MSG
Fault alert on application Test on host Fred

----------------------------------------
o What

  fault: Oh Snap!
  stack:
   : fred
   : blee

  user_name: Fernand
  url: http://bumblebeetuna/fred/blee
  path: /fred/blee
  status: 200
  method: POST
  request_time: 0.55
  ip: 

----------------------------------------
o Server

  host: Fred
  software: nginx/0.7.64
  ruby_version: ruby 1.8.7 (2009-06-12 patchlevel 174) [i686-darwin10.0.0]

----------------------------------------
o Params

  id: 10
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Session

  blee: Hello World
  fred:
   : 10
   : 20
   : 30

----------------------------------------
o Browser

  name: Chromey
  version: 1.12.23.54

----------------------------------------
o Headers

  Cache-Control: no-cache
  Content-Type: text/html; charset=utf-8
  Content-Length: 17911
  Set-Cookie: fred

----------------------------------------
o Client

  platform: Windoze
  os: Windows NT
  version: 3.5
  local: en-us


===============================================================
Powered by Rackamole. This message was generated automatically.
Please do not respond directly.
MSG
  end
  
end