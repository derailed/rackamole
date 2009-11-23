require 'hitimes'
require 'json'
require 'mongo'

# BOZO !! - Need args validator or use dsl as the args are out of control...
module Rack
  class Mole
    
    # Initialize The Mole rack component. It is recommended that you specify at a minimum a user_key to track
    # interactions on a per user basis. If you wish to use the mole for the same application in different 
    # environments you should set the environment attribute RAILS_ENV for example. The perf_threshold setting 
    # is also recommended to get performance notifications should your web app start sucking. 
    # By default your app will be moleable upon installation and you should see mole features spewing out in your 
    # logs. This is the default setting. Alternatively you can store mole information in a mongo database by 
    # specifying a different store option.
    #
    # === Options
    #
    # :app_name       :: The name of the application (Default: Moled App)
    # :environment    :: The environment for the application ie :environment => RAILS_ENV
    # :perf_threshold :: Any request taking longer than this value will get moled. Default: 10secs
    # :moleable       :: Enable/Disable the MOle (Default:true)
    # :store          :: The storage instance ie log file or mongodb [Default:stdout]
    # :user_key       :: If sessions are enable, this represents the session key for the user name or 
    #                    user_id.
    # ==
    #  If the username resides in the session hash with key :user_name the you can use:
    #    :user_key => :user_name
    #  Or you can eval it on the fly - though this will be much slower and not recommended
    #    :user_key => { :session_key => :user_id, :extractor => lambda{ |id| User.find( id ).name} }
    # ==
    #
    # :excluded_paths:: Exclude paths that you do not wish to mole by specifying an array of regular expresssions.
    # :twitter_auth  :: You can setup the MOle twit interesting events to a private (public if you indulge pain!) twitter account.
    #                   Specified your twitter account information using a hash with :username and :password key
    # :twitt_on      :: You must configure your twitter auth and configuration using this hash. By default this option is disabled.
    # ==
    #   :twitt_on => { :enabled  => false, :features => [Rackamole.perf, Rackamole.fault] }
    # ==
    # ==== BOZO! currently there is not support for throttling or monitoring these alerts. 
    # ==
    # :emails        :: The mole can be configured to send out emails bases on interesting mole features.
    #                   This feature uses actionmailer. You must specify a hash for the from and to options.
    # ==
    #   :emails => { :from => 'fred@acme.com', :to => ['blee@acme.com', 'doh@acme.com'] }
    # ==
    # :mail_on      :: Hash for email alert triggers. May be enabled or disabled per env settings. Default is disabled
    # ==
    #   :mail_on => {:enabled => true, :features => [Rackamole.perf, Rackamole.fault] }
    def initialize( app, opts={} )
      @app = app
      init_options( opts )
      validate_options
    end
          
    # Entering the MOle zone...
    # Watches incoming requests and report usage information. The mole will also track request that
    # are taking longer than expected and also report any requests that are raising exceptions. 
    def call( env )
      # Bail if application is not moleable
      return @app.call( env ) unless moleable?
            
      status, headers, body = nil
      elapsed = Hitimes::Interval.measure do
        begin
          status, headers, body = @app.call( env )
        rescue => boom
          env['mole.exception'] = boom
          mole_feature( env, elapsed, status, headers, body )
          raise boom
        end
      end
      mole_feature( env, elapsed, status, headers, body )
      return status, headers, body
    end 

  # ===========================================================================  
  private
       
    attr_reader :options #:nodoc:
        
    # Load up configuration options
    def init_options( opts )
      @options = default_options.merge( opts )      
    end
    
    # Mole default options
    def default_options
      { 
        :app_name        =>  "Moled App",
        :excluded_paths  =>  [/.?\.ico/, /.?\.png/],
        :moleable        =>  true,
        :perf_threshold  =>  10,
        :store           =>  Rackamole::Store::Log.new,
        :twitt_on        =>  { :enabled => false, :features => [Rackamole.perf, Rackamole.fault] },
        :mail_on         =>  { :enabled => false, :features => [Rackamole.perf, Rackamole.fault] }
      }
    end
           
    # Validates all configured options... Throws error if invalid configuration
    def validate_options
      %w[app_name moleable perf_threshold store].each do |k|
        raise "[M()le] -- Unable to locate required option key `#{k}" unless options[k.to_sym]
      end
    end
    
    # Send moled info to store and potentially send out alerts...
    def mole_feature( env, elapsed, status, headers, body )
      attrs = mole_info( env, elapsed, status, headers, body )
      
      # send info to configured store
      options[:store].mole( attrs )
      
      # send email alert ?
      if configured?( :emails, [:from, :to] ) and alertable?( options[:mail_on], attrs[:type] )
        Rackamole::Alert::Emole.deliver_alert( options[:emails][:from], options[:emails][:to], attrs ) 
      end
      
      # send twitter alert ?
      if configured?( :twitter_auth, [:username, :password] ) and alertable?( options[:twitt_on], attrs[:type] )
        twitt.send_alert( attrs ) 
      end      
    rescue => boom
      $stderr.puts "!! MOLE RECORDING CRAPPED OUT !! -- #{boom}"
      boom.backtrace.each { |l| $stderr.puts l }
    end
    
    # Check if an options is set and configured
    def configured?( key, configs )
      return false unless options[key]
      configs.each { |c| return false unless options[key][c] }
      true
    end
    
    # Check if feature should be send to alert clients ie email or twitter
    def alertable?( filters, type )
      return false if !filters or filters.empty? or !filters[:enabled]
      filters[:features].include?( type )
    end
    
    # Create or retrieve twitter client
    def twitt
      @twitt ||= Rackamole::Alert::Twitt.new( options[:twitter_auth][:username], options[:twitter_auth][:password] )
    end
        
    # Check if this request should be moled according to the exclude filters        
    def mole_request?( request )
      options[:excluded_paths].each do |exclude_path|
        return false if request.path.match( exclude_path )
      end
      true
    end
    
    # Extract interesting information from the request
    def mole_info( env, elapsed, status, headers, body )      
      request = Rack::Request.new( env )
      info    = OrderedHash.new
         
      # dump( env )
                  
      return info unless mole_request?( request )
                        
      session     = env['rack.session']      
      route       = get_route( request )

      ip, user_agent = identify( env )
      user_id        = nil
      user_name      = nil
           
      # BOZO !! This could be slow if have to query db to get user name...
      # Preferred store username in session and give at key
      user_key = options[:user_key]
      if session and user_key
        if user_key.instance_of? Hash
          user_id  = session[ user_key[:session_key] ]
          if user_key[:extractor]
            user_name = user_key[:extractor].call( user_id )
          end
        else
          user_name = session[user_key]
        end
      end
          
      info[:type]         = (elapsed and elapsed > options[:perf_threshold] ? Rackamole.perf : Rackamole.feature)
      info[:app_name]     = options[:app_name]
      info[:environment]  = options[:environment] || "Unknown"
      info[:user_id]      = user_id      if user_id
      info[:user_name]    = user_name || "Unknown"
      info[:ip]           = ip
      info[:browser]      = id_browser( user_agent )
      info[:host]         = env['SERVER_NAME']
      info[:software]     = env['SERVER_SOFTWARE']
      info[:request_time] = elapsed if elapsed
      info[:url]          = request.url
      info[:method]       = env['REQUEST_METHOD']
      info[:path]         = request.path
      info[:route_info]   = route if route
      
      # Dump request params
      unless request.params.empty?
        info[:params] = OrderedHash.new
        request.params.keys.sort.each { |k| info[:params][k.to_sym] = request.params[k].to_json }
      end
            
      # Dump session var
      if session and !session.empty?
        info[:session] = OrderedHash.new 
        session.keys.sort{ |a,b| a.to_s <=> b.to_s }.each { |k| info[:session][k.to_sym] = session[k].to_json }
      end
      
      # Check if an exception was raised. If so consume it and clear state
      exception = env['mole.exception']
      if exception
        info[:ruby_version]   = %x[ruby -v]
        info[:fault]          = exception.to_s
        info[:stack]          = trim_stack( exception )
        info[:type]           = Rackamole.fault
        env['mole.exception'] = nil
      end      
      info
    end
        
    # Attempts to detect browser type from agent info.
    # BOZO !! Probably more efficient way to do this...
    def browser_types() @browsers ||= [ 'Firefox', 'Safari', 'MSIE 8.0', 'MSIE 7.0', 'MSIE 6.0', 'Opera', 'Chrome' ] end
      
    def id_browser( user_agent )
      return "N/A" if !user_agent or user_agent.empty?
      browser_types.each do |b|
        return b if user_agent.match( /.*?#{b.gsub(/\./,'\.')}.*?/ )
      end
      "N/A"
    end
    
    # Trim stack trace
    def trim_stack( boom )
      boom.backtrace[0...4]
    end

    # Identify request ie ip and browser configuration   
    def identify( request_env )
      return request_env['HTTP_X_FORWARDED_FOR'] || request_env['REMOTE_ADDR'], request_env['HTTP_USER_AGENT']
    end
            
    # Checks if this application is moleable
    def moleable?
      options[:moleable]
    end
    
    # Fetch route info if any...
    def get_route( request )
      return nil unless defined?( RAILS_ENV )
      
      # Check for invalid route exception...
      begin
        return ::ActionController::Routing::Routes.recognize_path( request.path, {:method => request.request_method.downcase.to_sym } )
      rescue
        return nil
      end
    end
    
    # Dump env to stdout
    # def dump( env, level=0 )
    #   env.keys.sort{ |a,b| a.to_s <=> b.to_s }.each do |k|
    #     value = env[k]
    #     if value.respond_to?(:each_pair) 
    #       puts "%s %-#{40-level}s" % ['  '*level,k]
    #       dump( env[k], level+1 )
    #     elsif value.instance_of?(::ActionController::Request) or value.instance_of?(::ActionController::Response) 
    #       puts "%s %-#{40-level}s %s" % [ '  '*level, k, value.class ]
    #     else
    #       puts "%s %-#{40-level}s %s" % [ '  '*level, k, value.inspect ]
    #     end        
    #   end
    # end
  end
end