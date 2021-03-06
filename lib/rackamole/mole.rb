require 'hitimes'
require 'json'
require 'mongo'
require 'yaml'

# TODO - add recording for response
# TODO - need plugable archictecture for alerts and stores
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
    # :config_file    :: This option will load rackamole options from a file versus individual options. 
    #                    You can leverage yaml and erb with the current rackamole context to specify each of
    #                    the following options but within a yaml file. This gives more flexibility to customize
    #                    the rack component for specific environment. You can specify the :environment option or
    #                    the default will be development.
    # :app_name       :: The name of the application (Default: Moled App)
    # :log_level      :: Rackamole logger level. (Default: info )
    # :environment    :: The environment for the application ie :environment => RAILS_ENV
    # :perf_threshold :: Any request taking longer than this value will get moled. Default: 10secs
    # :moleable       :: Enable/Disable the MOle (Default:true)
    # :store          :: The storage instance ie log file or mongodb [Default:stdout]
    # :expiration     :: Number of seconds to alert expiration. The mole will not keep sending alert if a particular
    #                    mole type has been reported in the past. This threshold specifies the limit at which
    #                    the previously sent alerts will expire and thus will be sent again. 
    #                    For instance, it might be the case that the app is consistently slow for a particular action.
    #                    On the first encounter an alert will be sent ( if configured ). Any subsequent requests for this action
    #                    will not fire an alert until the expiration threshold is hit. The default is 1 hour. 
    #                    Setting this threshold to Rackamole::Stash::Collector::NEVER will result in alerts being fired continually.
    # :user_key       :: If sessions are enable, this represents the session key for the user name or 
    #                    user_id.
    # ==
    #  If the username resides in the session hash with key :user_name the you can use:
    #    :user_key => :user_name
    #  Or you can eval it on the fly - though this will be much slower and not recommended
    #    :user_key => { :session_key => :user_id, :extractor => lambda{ |id| User.find( id ).name} }
    # ==
    #
    # :mole_excludes :: Exclude some of the parameters that the mole would normally include. The list of 
    #                   customizable parameters is: software, ip, browser type, url, path, status, headers and body.
    #                   This options takes an array of symbols. Defaults to [:body].
    # :perf_excludes :: Specifies a set of paths that will be excluded when a performance issue is detected.
    #                   This is useful when certain requests are known to be slow. When a match is found an
    #                   alert won't be issued but the context will still be moled.
    # ==
    #   Don't send an alert when perf is found on /blee/fred. Don't alert on /duh unless the request took longer than 10 secs 
    #   :perf_excludes => [ {:context => '/blee/fred}, {:context => /^\/duh.*/, :threshold => 10 } ]
    # ==
    # :excluded_paths:: Exclude paths that you do not wish to mole by specifying an array of regular expresssions.
    # :param_excludes:: Exempt certain sensitive request parameters from being logged to the mole. Specify an array of keys
    #                   as symbols ie [:password, :card_number].
    # :session_excludes:: Exempt session params from being logged by the mole. Specify an array of keys as symbols
    #                   ie [:fred, :blee] to exclude session[:fred] and session[:blee] from being stored.
    # :twitter       :: Set this option to have the mole twitt certain alerts. You must configure your twitter auth 
    #                   via the :username and :password keys and :alert_on with an array of mole types you
    #                   wish to be notified on.
    # ==
    #   :twitter => { :username => 'fred', :password => 'blee', :alert_on => [Rackamole.perf, Rackamole.fault] }
    # ==
    # ==== BOZO! currently there is not support for throttling or monitoring these alerts. 
    # ==
    # :email        :: The mole can be configured to send out emails bases on interesting mole features.
    #                  This feature uses Pony to send out the email. You must specify a hash with the following keys :from, :to 
    #                  and :alert_on options to indicate which mole type your wish to be alerted on. 
    #                  See Pony docs for custom options for your emails
    # ==
    #   :email => { :from => 'fred@acme.com', :to => ['blee@acme.com', 'doh@acme.com'], :alert_on => [Rackamole.perf, Rackamole.fault]  }
    # ==
    #
    # :growl        :: You can set up rackamole to send growl notifications when certain features
    #                  are encounters in the same way email and twitt alerts works. The :to options
    #                  describes a collection of hash values with the ip and optional password to the recipients.
    # ==
    #   :growl => { :to => [{ :ip => '1.1.1.1' }], :alert_on => [Rackamole.perf, Rackamole.fault]  }
    # ==    
    def initialize( app, opts={} )    
      @app       = app
      init_options( opts )
      validate_options
      @logger = Rackamole::Logger.new( :logger_name => 'RACKAMOLE', :log_level => options[:log_level] )
    end
          
    # Entering the MOle zone...
    # Watches incoming requests and report usage information. The mole will also track request that
    # are taking longer than expected and also report any requests that are raising exceptions. 
    def call( env )      
      # Bail if application is not moleable
      return @app.call( env ) unless moleable?
                
      @stash = env['mole.stash'] if env['mole.stash']      
      @stash = Rackamole::Stash::Collector.new( options[:app_name], options[:environment], options[:expiration] ) unless stash
            
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
       
    attr_reader :options, :logger, :stash #:nodoc:
        
    # Load up configuration options
    def init_options( opts )
      if opts[:config_file] && (env = opts[:environment] || "development")
        raise "Unable to find rackamole config file #{opts[:config_file]}" unless ::File.exists?( opts[:config_file] )
        begin
          opts = YAML.load( ERB.new( IO.read( opts[:config_file] ) ).result( binding ) )[env]
          opts[:environment] = env 
        rescue => boom
          raise "Unable to parse Rackamole config file #{boom}"
        end        
      end      
      @options = default_options.merge( opts )      
    end
    
    # Mole default options
    def default_options
      { 
        :moleable        =>  true,    
        :log_level       =>  :info,
        :expiration      =>  60*60, # 1 hour
        :environment     =>  'development',
        :excluded_paths  =>  [/.*?\/stylesheets\/.*/, /.*?\/javascripts\/.*/,/\.*?\/images\/.*/ ],
        :mole_excludes   =>  [:body],
        :perf_threshold  =>  10.0,
        :store           =>  Rackamole::Store::Log.new
      }
    end
           
    # Validates all configured options... Throws error if invalid configuration
    def validate_options
      return unless options[:moleable]
      
      %w[app_name environment perf_threshold store].each do |k|
        raise "[M()le] -- Unable to locate required option key `#{k}" unless options[k.to_sym]
      end
      
      # Barf early if something is wrong in the configuration
      configured?( :twitter, [:username, :password, :alert_on], true )
      configured?( :email  , [:from, :to, :alert_on], true )
      configured?( :growl  , [:to, :alert_on], true )      
    end
    
    # Send moled info to store and potentially send out alerts...
    def mole_feature( env, elapsed, status, headers, body )   
      env['mole.stash'] = stash
      
      attrs = mole_info( env, elapsed, status, headers, body )

      # If nothing to mole bail out!
      return if attrs.empty?

      # send info to configured store
      options[:store].mole( attrs )
      
      # Check for dups. If we've reported this req before don't report it again...
      unless duplicated?( env, attrs )
        # send email alert ?
        if alertable?( :email, attrs[:type] )
          logger.debug ">>> Sending out email on mole type #{attrs[:type]} from #{options[:email][:from]} to #{options[:email][:to].join( ", ")}"
          Rackamole::Alert::Emole.deliver_alert( logger, options, attrs ) 
        end

        # send growl alert ?
        if alertable?( :growl, attrs[:type] )
          logger.debug ">>> Sending out growl on mole type #{attrs[:type]} to @#{options[:growl][:to].inspect}"
          Rackamole::Alert::Growl.deliver_alert( logger, options, attrs )
        end
      
        # send twitter alert ?
        if alertable?( :twitter, attrs[:type] )
          logger.debug ">>> Sending out twitt on mole type #{attrs[:type]} on @#{options[:twitter][:username]}"
          Rackamole::Alert::Twitt.deliver_alert( logger, options, attrs )
        end
      end
    rescue => boom
      logger.error "!! MOLE RECORDING CRAPPED OUT !! -- #{boom}"
      boom.backtrace.each { |l| logger.error l }
    end
    
    # Check if we've already seen such an error
    def duplicated?( env, attrs )
      # Skip features for now...
      return true if attrs[:type] == Rackamole.feature
      
      # Don't bother if expiration is set to never. ie fire alerts all the time
      return false if options[:expiration] == Rackamole::Stash::Collector::NEVER
      
      now    = Time.now
      app_id = [attrs[:app_name], attrs[:environment]].join( '_' )
      path   = attrs[:route_info] ? "#{attrs[:route_info][:controller]}#{attrs[:route_info][:action]}" : attrs[:path]      
                        
      # Check expired entries
      stash.expire!
      
      # check if we've seen this error before. If so stash it.
      if attrs[:type] == Rackamole.fault
        return stash.stash_fault( path, attrs[:stack].first, now.utc )
      end
      
      # Check if we've seen this perf issue before. If so stash it
      if attrs[:type] == Rackamole.perf
        # Don't send alert if exempted
        return true if perf_exempt?( attrs[:path], attrs[:request_time])
        return stash.stash_perf( path, attrs[:request_time], now.utc )
      end      
    end
    
    # Check if request should be exempted from perf alert
    def perf_exempt?( path, req_time )
      return false unless option_defined?( :perf_excludes )
      options[:perf_excludes].each do |hash|
        context    = hash[:context]
        threshold  = hash[:threshold]
        time_trip  = (threshold ? req_time <= threshold : true)
        
        if context.is_a? String
          return true if path == context and time_trip
        elsif context.is_a? Regexp
          return true if path.match(context) and time_trip
        end
      end
      false
    end
    
    # Check if an option is defined
    def option_defined?( key )
      options.has_key?(key) and options[key]
    end
    
    # Check if an options is set and configured
    def configured?( key, configs, optional=true )
      return false if optional and !options.has_key?(key)
      raise "Missing option key :#{key}" unless options.has_key?(key)
      configs.each do |c|
        raise "Invalid value for option :#{key}. Expecting a hash with symbols [#{configs.join(',')}]" unless options[key].respond_to? :key?
        unless options[key].key?(c)
          raise "Option :#{key} is not properly configured. Missing #{c.inspect} in [#{options[key].keys.sort{|a,b| a.to_s <=> b.to_s}.join(',')}]"
        end
      end
      true
    end
    
    # Check if feature should be send to alert clients ie email or twitter
    def alertable?( filter, type )
      return false unless configured?( filter, [:alert_on] )
      return false unless options[filter][:alert_on]
      options[filter][:alert_on].include?( type )
    end
            
    # Check if this request should be moled according to the exclude filters        
    def mole_request?( request )
      if options.has_key?( :excluded_paths ) and options[:excluded_paths]
        options[:excluded_paths].each do |exclude_path|
          exclude_path = Regexp.new( exclude_path ) if exclude_path.is_a?( String )
          if request.path =~ exclude_path
            logger.debug ">>> Excluded request -- #{request.path} using exclude flag #{exclude_path}"
            return false 
          end
        end
      end
      true
    end
    
    # Extract interesting information from the request
    def mole_info( env, elapsed, status, headers, body )
      request  = Rack::Request.new( env )
      response = nil
      begin
        response = Rack::Response.new( body, status, headers )
      rescue
        ;
      end
        
      info     = BSON::OrderedHash.new
                           
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
      info[:user_id]      = user_id if user_id
      info[:user_name]    = user_name || "Unknown"
      info[:host]         = env['SERVER_NAME']
      info[:request_time] = elapsed if elapsed
      info[:method]       = env['REQUEST_METHOD']
      info[:route_info]   = route if route      
      info[:created_at]   = Time.now.utc
            
      # Optional elements...
      mole?( :software  , info, env['SERVER_SOFTWARE'] )
      mole?( :ip        , info, ip )
      mole?( :url       , info, request.url )
      mole?( :path      , info, request.path )
      mole?( :status    , info, status )
      mole?( :headers   , info, headers )
      mole?( :body      , info, response.body ) if response
      
      # Gather up browser and client machine info
      agent_info = Rackamole::Utils::AgentDetect.parse( user_agent )
      %w(browser machine).each { |type| mole?(type.to_sym, info, agent_info[type.to_sym] ) }

      # Dump request params
      unless request.params.empty?
        info[:params] = filter_params( request.params, options[:param_excludes] || [] )
      end
      if route
        info[:params] ||= {}
        info[:params].merge!( filter_params( params_from_route( route ), options[:param_excludes] || [] ) )
      end
            
      # Dump session var
      if session and !session.empty?
        info[:session] = filter_params( session, options[:session_excludes] || [] )
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
    
    # Parse out rails request params if in rails env
    def params_from_route( route )
      params = {}
      except = [:controller, :action]
      route.each_pair do |k,v|
        next if except.include?( k )
        params[k] = v
      end
      params
    end
    
    # check exclusion to see if the information should be moled
    def mole?( key, stash, value )
      return stash[key] = value if !options[:mole_excludes] or options[:mole_excludes].empty?
      stash[key] = (options[:mole_excludes].include?( key ) ? nil : value)
    end
    
    # filters out params hash and convert values to json
    def filter_params( source, excludes, nest=false )
       results = nest ? {} : BSON::OrderedHash.new
       source.keys.sort{ |a,b| a.to_s <=> b.to_s }.each do |k|
         unless excludes.include? k.to_sym
           results[k.to_sym] = if source[k].is_a?(Hash)
                         filter_params( source[k], excludes, true)
                       else
                         source[k]
                       end
           results[k.to_sym] = results[k.to_sym].to_json unless nest
         end
       end
       results
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
        return Rails.application.routes.recognize_path( request.path, {:method => request.request_method.downcase.to_sym } )        
      rescue => boom      
        return nil
      end
    end
    
    # # Debug - Dump env to stdout
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
