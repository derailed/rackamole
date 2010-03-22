require 'twitter'

module Rackamole::Alert
  # Leverage twitter as a notification client. You can setup a private twitter account
  # and have your moled app twitt exception/perf alerts...
  class Twitt

    # Twitt an alert        
    def self.deliver_alert( logger, options, attrs )
      @twitt ||= Twitt.new( logger, options[:twitter][:username], options[:twitter][:password] )
      @twitt.send_alert( attrs )
    end
            
    # This class is used to send out moled twitter notification. This feature is enabled
    # by setting the :twitter option on the Rack::Mole. When a moled 
    # feature comes around it will be twitted on your configured account. This allow your
    # app to twitt about it's status and issues. Currently there are no provisions to throttle
    # the twitts, hence sending out twitt notifications of every moled features would not be 
    # a very good idea. Whereas sending twitts when your application bogs down or throws exception,
    # might be more appropriate. Further work will take place to throttle these events...
    # Creating a private twitter account and asking folks in your group to follow might be a
    # nice alternative to email.
    #
    # NOTE: This is just an alert mechanism. All moled events will be either logged or persisted in the db
    # regardless.
    #
    # === Params:
    # username :: The name on the twitter account
    # password :: The password of your twitter account
    # logger   :: Instance of the rackamole logger
    def initialize( logger, username, password )
      raise "You must specify your twitter account credentials" unless username or password
      @username = username
      @password = password
      @logger   = logger
    end
       
    # Send out a twitt notification based of the watched features. A short message will be blasted to your twitter
    # account based on information reported by the mole. The twitt will be automatically truncated
    # to 140 chars.
    #
    # === Params:
    # args :: The moled info for a given feature. 
    #
    def send_alert( args )
      twitt_msg = "#{args[:app_name]} on #{format_host(args[:host])} - #{args[:user_name]}\n#{display_feature(args)}"
      twitt_msg = case args[:type]
        when Rackamole.feature
          "[Feature] #{twitt_msg}"
        when Rackamole.perf 
          "[Perf] #{twitt_msg}\n#{format_time(args[:request_time])} secs"
        when Rackamole.fault
          "[Fault] #{twitt_msg}\n#{args[:fault]}"
      end
      if twitt_msg
        twitt_msg += " - #{args[:created_at].strftime( "%H:%M:%S")}"
        twitt.status( :post, truncate( twitt_msg ) ) 
      end
      twitt_msg
    rescue => boom
       logger.error "Rackamole twitt alert failed with error `#{boom}"
    end                                  
        
    # =========================================================================
    private
    
       attr_reader :logger, :username, :password #:nodoc:
       
       # Fetch twitter connection...
       def twitt
         @twitt ||= ::Twitter::Client.new( :login => username, :password => password )
       end
       
       # Display controller/action or path depending on frmk used...
       def display_feature( args )
         return args[:path] unless args[:route_info]
         "#{args[:route_info][:controller]}##{args[:route_info][:action]}"
       end

      # Format host ie fred@blee.com => fred
      def format_host( host )
        return host.gsub( /@.+/, '' ) if host =~ /@/
        host
      end
      
      # Format precision on request time
      def format_time( time )
        ("%4.2f" % time).to_f
      end
      
      # Truncate for twitt max size      
      # BOZO !! This will be hosed if not 1.9 for multibyte chars 
      def truncate(text, length = 140, truncate_string = "...")
        return "" if text.nil?
        l = length - truncate_string.size
        text.size > length ? (text[0...l] + truncate_string).to_s : text
      end       
  end
end