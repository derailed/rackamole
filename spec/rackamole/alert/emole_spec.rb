require File.join(File.dirname(__FILE__), %w[.. .. spec_helper])

describe Rackamole::Alert::Emole do
  
  before( :each ) do
    @from = "fernand"
    @to   = %w[fernand bobo blee]
    
    @expected = TMail::Mail.new
    @expected.set_content_type 'text', 'plain', { 'charset' => 'utf-8' }
    @expected.mime_version = '1.0'
    @expected.from    = @from
    @expected.to      = @to

    @options = { :email => { :from => @from, :to => @to }, :perf_threshold => 10 }
    
    @args = OrderedHash.new
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

    @args[:params]      = OrderedHash.new
    @args[:params][:id]   = 10
    @args[:params][:fred] = [10,20,30]
    
    @args[:session] = OrderedHash.new
    @args[:session][:blee] = "Hello World"
    @args[:session][:fred] = [10,20,30]
    
    @args[:headers] = OrderedHash.new
    @args[:headers]['Cache-Control']  = "no-cache"
    @args[:headers]['Content-Type']   = "text/html; charset=utf-8"
    @args[:headers]['Content-Length'] = "17911"
    @args[:headers]['Set-Cookie']     = "fred"

    @args[:browser] = OrderedHash.new
    @args[:browser][:name]    = "Chromey"
    @args[:browser][:version] = "1.12.23.54"
    
    @args[:machine] = OrderedHash.new
    @args[:machine][:platform] = "Windoze"
    @args[:machine][:os]       = "Windows NT"
    @args[:machine][:version]  = "3.5"
    @args[:machine][:local]    = "en-us"    
    
  end
  
  describe "#alert" do
    
    it "should send a feature email correctly" do
      # @expected.subject = "[M()le] (Feature) -Test@Fred- for user Fernand"
      @expected.body    = feature_body
# puts Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )
      Rackamole::Alert::Emole.deliver_alert( nil, @options, @args ).should == @expected.body_port.to_s
    end

    it "should send a perf email correctly" do
      @args[:type] = Rackamole.perf
      @args[:request_time] = 15.2
      # @expected.subject = "[M()le] (Performance:10.0) -Test@Fred- for user Fernand"
      @expected.body    = perf_body
# puts Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )      
      Rackamole::Alert::Emole.deliver_alert( nil, @options, @args ).should == @expected.body_port.to_s
    end

    it "should send a fault email correctly" do
      @args[:type]   = Rackamole.fault
      @args[:fault]  = 'Oh Snap!'
      @args[:stack]  = ['fred', 'blee']
      # @expected.subject = "[M()le] (Fault) -Test@Fred- for user Fernand"
      @expected.body    = fault_body
# puts Rackamole::Alert::Emole.deliver_alert( nil, @options, @args )      
      Rackamole::Alert::Emole.deliver_alert( nil, @options, @args ).should == @expected.body_port.to_s
    end
  end
  
  def feature_body
msg=<<MSG
Feature alert on application Test on host Fred

----------------------------------------
o What

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

  request_time: 15.2/10
  url: http://bumblebeetuna/fred/blee
  path: /fred/blee
  status: 200
  method: POST
  request_time: 15.2
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