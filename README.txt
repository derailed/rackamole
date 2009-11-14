== RackAMole
  Your web application observer...
  
== DESCRIPTION:

The MOle is a rack application that monitors user interactions with your web site. We are not 
talking about counting page hits here. The MOle tracks all the information available to capture
the essence of a user interaction with your application. Using the MOle, you are able to see
which feature is a hit or a bust. As an added bonus, the MOle also track performance and exceptions 
that might have escaped your test suites or alpha env. To boot your managers will love you for it! 

Whether you are releasing a new application or improving on an old one, it is always a good thing 
to know if anyone is using your application and if they are, how they are using it. 
What features are your users most fond of and which features find their way into the abyss? 
You will be able to rapidly assess whether or not your application is a hit and if
your coolest features are thought as such by your users. You will be able to elegantly record user
interactions and leverage these findings for the next iteration of your application. 

== PROJECT INFORMATION

* Developer:  Fernand Galiana
* Blog:       liquidrail.com
* Site:       rackamole.com
* Twitter:    @rackamole
* Forum:      http://groups.google.com/group/rackamole
* Git:        git://github.com/derailed/rackamole.git

== FEATURES:

* Monitors Rails or Sinatra applications
* Captures the essence of the request as well as user information
* Tracks performance issues based on your latency threshold
* Tracks exceptions that might occurred during a request

== REQUIREMENTS:

* Logging
* Hitimes
* MongoDb

== INSTALL:

* sudo gem install rackamole

  NOTE: The gem is hosted on gemcutter.com - please update your gem sources if not 
  already specified
  
== USAGE:

=== Rails applications
  
  Edit your environment.rb file and add the following lines:
  
  require 'rackamole'
  config.middleware.use Rack::Mole, { :app_name => "My Cool App", :user_key => :user_name }

  This instructs the mole to start logging information to the console and look for the user name 
  in the session using the :user_name key. There are other options available, please take a look
  at the docs for more information.
  
=== Sinatra Applications

  Add the following lines in the config section and smoke it...
  
  require 'rackamole'
  configure do
    use Rack::Mole, { :app_name => "My Sinatra App", :user_key => :user_name }
  end
  
  This assumes that you have session enabled to identify a user if not the mole will log the user
  as 'Unknown'
  
== LICENSE:

(The MIT License)

Copyright (c) 2008 FIXME (different license?)

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.