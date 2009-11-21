require 'hitimes'
require 'json'
require 'mongo'

module Rack
  class Mole
    
    # Initialize The Mole with the possible options
    # <tt>:app_name</tt>    - The name of the application [Default: Moled App]
    # <tt>:environment</tt> - The environment for the application ie :environment => RAILS_ENV
    # <tt>:perf_threshold</tt> - Any request taking longer than this value will get moled [Default: 10]    
    # <tt>:moleable</tt>    - Enable/Disable the MOle [Default:true]
    # <tt>:store</tt>       - The storage instance ie log file or mongodb [Default:stdout]
    # <tt>:user_key</tt>    - If session is enable, the session key for the user name or user_id. ie :user_key => :user_name 
    def initialize( app, opts={} )
      @app = app
      init_options( opts )
    end
            
    def call( env )
      # Bail if application is not moleable
      return @app.call( env ) unless moleable?
            
      status, headers, body = nil
      elapsed = Hitimes::Interval.measure do
        begin
          status, headers, body = @app.call( env )
        rescue => boom
          env['mole.exception'] = boom
          @store.mole( mole_info( env, elapsed, status, headers, body ) )
          raise boom
        end
      end
      @store.mole( mole_info( env, elapsed, status, headers, body ) )
      return status, headers, body
    end 

  # ===========================================================================  
  private
       
    # Load up configuration options
    def init_options( opts )
      options          = default_options.merge( opts )      
      @environment     = options[:environment]
      @perf_threshold  = options[:perf_threshold]
      @moleable        = options[:moleable]
      @app_name        = options[:app_name]
      @user_key        = options[:user_key]
      @store           = options[:store]
      @excluded_paths  = options[:excluded_paths]
    end
    
    # Mole default options
    def default_options
      { 
        :app_name        =>  "Moled App",
        :excluded_paths  =>  [/.?\.ico/, /.?\.png/],
        :moleable        =>  true,
        :perf_threshold  =>  10,
        :store           =>  Rackamole::Store::Log.new
      }
    end
       
    # Check if this request should be moled according to the exclude filters        
    def mole_request?( request )
      @excluded_paths.each do |exclude_path|
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
      if session and @user_key
        if @user_key.instance_of? Hash
          user_id  = session[ @user_key[:session_key] ]
          if @user_key[:extractor]
            user_name = @user_key[:extractor].call( user_id )
          end
        else
          user_name = session[@user_key]
        end
      end
            
      info[:app_name]     = @app_name
      info[:environment]  = @environment || "Unknown"
      info[:user_id]      = user_id      if user_id
      info[:user_name]    = user_name || "Unknown"
      info[:ip]           = ip
      info[:browser]      = id_browser( user_agent )
      info[:host]         = env['SERVER_NAME']
      info[:software]     = env['SERVER_SOFTWARE']
      info[:request_time] = elapsed if elapsed
      info[:performance]  = (elapsed and elapsed > @perf_threshold)
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
        info[:stack]          = trim_stack( exception )
        env['mole.exception'] = nil
      end      
      info
    rescue => boom
      $stderr.puts "!! MOLE RECORDING CRAPPED OUT !! -- #{boom}"
      boom.backtrace.each { |l| $stderr.puts l }
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
      @moleable
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