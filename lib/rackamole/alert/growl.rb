require 'ruby-growl'

module Rackamole::Alert
  # Leverages growl as a notification client.
  class Growl

    # Twitt an alert        
    def self.deliver_alert( logger, options, attrs )
      @growl ||= Growl.new( logger, options[:growl][:to] )
      @growl.send_alert( attrs )
    end
            
    # Send a growl notification for particular moled feature. A growl will
    # be sent based on the configuration :growl defined on Rack::Mole component
    # This option must specify the to ip addresses and the conditions
    # that will trigger a growl defined by alert_on for the type of
    # moled features to track via email. The notification will be sent via UDP,
    # so you will need to make sure it is properly configured for your domain.
    #
    # NOTE: This is just a notification mechanism. All moled event will be either logged 
    # or persisted in the db regardless.
    #
    # === Parameters:
    # options    :: Mole options. The :growl key must contains :to addresses.
    # args       :: The gathered information from the mole.
    def initialize( logger, recipients )
      raise "You must specify your growl :to addresses" unless recipients
      @recipients = recipients
      @logger   = logger
      @growls   = {}
    end
       
    # Send out a growl notification based of the watched features. A short message will be blasted to your growl
    # client based on information reported by the mole.
    # === Params:
    # args :: The moled info for a given feature. 
    def send_alert( args )
      recipients.each do |recipient|
        buff  = "#{args[:user_name]}:#{display_feature(args)}"
        title = "#{args[:app_name]}(#{args[:environment]})"
        case args[:type]
          when Rackamole.feature
            type     = "Feature"
            title    = "[Feat] #{title}"
            msg      = buff
            priority = -2
            sticky   = false
          when Rackamole.perf
            type     = "Perf" 
            title    = "[Perf] #{title}"
            msg      = "#{buff} #{format_time(args[:request_time])} secs"
            priority = 2
            sticky   = true
          when Rackamole.fault
            type     = "Fault"
            title    = "[Fault] #{title}"
            msg      = "#{buff}\n#{args[:fault]}"
            priority = 2
            sticky   = true            
        end
        growl( recipient ).notify( type, title, msg, priority, sticky )
      end
    rescue => boom
       logger.error "Rackamole growl alert failed with error `#{boom}"
    end
        
    # =========================================================================
    private
    
       attr_reader :logger, :recipients #:nodoc:
       
       # Fetch or create growl application...
       def growl( recipient )
         return @growls[recipient[:ip]] if @growls[recipient[:ip]]
         growl = ::Growl.new( recipient[:ip], 'rackamole', %w(Feature Perf Fault), nil, recipient[:password] )
         @growls[recipient[:ip]] = growl
         growl
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