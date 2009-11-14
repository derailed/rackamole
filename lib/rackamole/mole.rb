require 'hitimes'
require 'mongo/util/ordered_hash'
require 'json'

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
      
      response = nil
      elapsed = Hitimes::Interval.measure do
        response = @app.call( env )
      end
      @store.mole( mole_info( env, elapsed ) )
      response
    end 

  # ===========================================================================  
  private
       
    # Load up configuration options
    def init_options( opts )
      options         = default_options.merge( opts )      
      @environment    = options[:environment]
      @perf_threshold = options[:perf_threshold]
      @moleable       = options[:moleable]
      @app_name       = options[:app_name]
      @user_key       = options[:user_key]
      @store          = options[:store]      
    end
    
    # Mole default options
    def default_options
      { 
        :app_name       =>  "Moled App",
        :moleable       =>  true,
        :perf_threshold =>  10,
        :store          =>  Rackamole::Store::Log.new
      }
    end
               
    # Extract interesting information from the request
    def mole_info( env, elapsed )      
      request     = Rack::Request.new( env )
      session     = env['rack.session']      
      route       = get_route( request )
      info        = OrderedHash.new
      ip, browser = identify( env )
      user_id     = nil
      user_name   = nil
           
      if session and @user_key
        if @user_key.instance_of? Symbol
          user_name = session[@user_key]
        elsif @user_key.instance_of? Hash
          user_id  = session[ @user_key[:session_key] ]
          if @user_key[:extractor]
            user_name = @user_key[:extractor].call( user_id )
          end
        end
      end
            
      info[:app_name]     = @app_name
      info[:environment]  = @environment if @environment
      info[:user_id]      = user_id      if user_id
      info[:user_name]    = user_name || "Unknown"
      info[:ip]           = ip
      info[:browser]      = browser
      info[:request_time] = elapsed if elapsed
      info[:perf_issue]   = (elapsed and elapsed > @perf_threshold)
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
      ::ActionController::Routing::Routes.recognize_path( request.path, {:method => request.request_method } )
    end
  end
end