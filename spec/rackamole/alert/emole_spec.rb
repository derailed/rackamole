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

    @args = OrderedHash.new
    @args[:type]      = Rackamole.feature
    @args[:app_name]  = 'Test'
    @args[:host]      = 'Fred'
    @args[:user_name] = 'Fernand'
  end
  
  describe "#alert" do
    
    it "should send a feature email correctly" do
      @expected.subject = "[M()le] (Feature) -Test@Fred- for user Fernand"
      @expected.body    = feature_body      
      Rackamole::Alert::Emole.create_alert( @from, @to, @args ).body_port.to_s.should == @expected.body_port.to_s
    end

    it "should send a perf email correctly" do
      @args[:type] = Rackamole.perf
      @args[:request_time] = 10.0
      @expected.subject = "[M()le] (Performance:10.0) -Test@Fred- for user Fernand"
      @expected.body    = perf_body
      Rackamole::Alert::Emole.create_alert( @from, @to, @args ).body_port.to_s.should == @expected.body_port.to_s
    end

    it "should send a fault email correctly" do
      @args[:type]   = Rackamole.fault
      @args[:fault]  = 'Oh Snap!'
      @args[:stack]  = ['fred', 'blee']
      @args[:params] = { :id => 10 }
      @expected.subject = "[M()le] (Fault) -Test@Fred- for user Fernand"
      @expected.body    = fault_body
      Rackamole::Alert::Emole.create_alert( @from, @to, @args ).body_port.to_s.should == @expected.body_port.to_s
    end

  end
  
  
  def feature_body
msg=<<MSG
A watched feature was triggered in application `Test on host `Fred

Details...

 type                                     0
 app_name                                 \"Test\"
 host                                     \"Fred\"
 user_name                                \"Fernand\"

- Your Rackamole

This message was generated automatically. Please do not respond directly.
MSG
  end
  
  def perf_body
msg=<<MSG
A watched feature was triggered in application `Test on host `Fred

Details...

 type                                     1
 app_name                                 \"Test\"
 host                                     \"Fred\"
 user_name                                \"Fernand\"
 request_time                             10.0

- Your Rackamole

This message was generated automatically. Please do not respond directly.
MSG
  end

  def fault_body
msg=<<MSG
A watched feature was triggered in application `Test on host `Fred

Details...

 type                                     2
 app_name                                 \"Test\"
 host                                     \"Fred\"
 user_name                                \"Fernand\"
 fault                                    \"Oh Snap!\"
 stack                                   
   fred                                   
   blee                                   
 params                                  
   id                                      10

- Your Rackamole

This message was generated automatically. Please do not respond directly.
MSG
  end
  
end