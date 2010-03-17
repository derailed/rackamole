require 'mail'
require 'erubis'

module Rackamole::Alert
  class Emole
    
    # retrieves erb template dir
    def self.template_root() @template_root ||= File.join( File.dirname(__FILE__), %w[templates] ); end
        
    # Send an email notification for particular moled feature. An email will
    # be sent based on the configuration :email defined on the
    # Rack::Mole component. This option must specify the to and from addresses and the conditions
    # that will trigger the email defined by alert_on for the type of
    # moled features to track via email. The notification will be sent via Mail,
    # so you will need to make sure it is properly configured for your domain.
    # NOTE: This is just a notification mechanism. All moled event will be either logged 
    # or persisted in the db regardless.
    #
    # === Parameters:
    # options    :: Mole options. The :email key minimaly contains :from for the from address. Must be a valid domain.
    #            :: And a :to, n array of email addresses for recipients to be notified.
    # args       :: The gathered information from the mole.
    #
    def self.deliver_alert( logger, options, args )
      @options   = options
      @args      = args
      tmpl       = File.join( template_root, %w[alert.erb] )
      template   = Erubis::Eruby.new( IO.read( tmpl ), :trim => true )
      body       = template.result( binding )
      subject    = "Rackamole <#{alert_type( args )}> #{request_time?( args )}on #{args[:app_name]}.#{args[:host]} for user #{args[:user_name]}"
      
      mail = Mail.new do
        from    options[:email][:from]
        to      options[:email][:to]
        subject subject
        body    body
      end      
      mail.deliver!      
      mail
    rescue => boom
      boom.backtrace.each { |l| logger.error l }
      logger.error( "Rackamole email alert failed with error `#{boom}" )
    end
            
    def self.section( title )
      buff = []
      buff << "-"*40      
      buff << "o #{title.capitalize}\n"      
      buff << self.send( title.downcase )
      buff << "\n"
      buff.join( "\n" )      
    end
    
    # =========================================================================
    private

      def self.args
        @args
      end
      
      def self.humanize( key )
        key
      end
      
      def self.feature_type
        case args[:type]
          when Rackamole.feature
            "Feature"
          when Rackamole.perf
            "Performance"
          when Rackamole.fault
            "Fault"  
        end
      end
      
      # Format args and spit out into buffer
      def self.spew( key, silent=false )
        buff = []
        
        _spew( buff, '--', (silent ? '' : '  '), key, args[key], silent )
        buff.join( "\n" )
      end
      def self._spew( buff, sep, indent, key, value, silent )
        if value.is_a?( Hash )
          buff << "#{indent}#{humanize( key )}:" unless silent
          value.each_pair{ |k,v| _spew( buff, sep, indent+"  ", k, v, false ) }
        elsif value.is_a?( Array )
          buff << "#{indent}#{humanize( key )}:" unless silent
          value.each { |s| _spew( buff, sep, indent+" ", '', s, false ) }
        else
          buff << "#{indent}#{humanize( key )}: #{value}"
        end
      end
      
      # What just happened?
      def self.what
        buff = []
        case args[:type]
          when Rackamole.fault
            buff << spew( :fault ) << spew( :stack ) + "\n"
          when Rackamole.perf
            buff << "#{spew( :request_time )}/#{@options[:perf_threshold]}"
        end
        buff << spew( :user_name) << spew( :url ) << spew( :path ) << spew( :status ) 
        buff << spew( :method ) << spew( :request_time ) << spew( :ip )
        buff.join( "\n" )
      end      
      def self.server()  [ spew( :host ), spew( :software ), spew( :ruby_version ) ]; end
      def self.client()  [ spew( :machine, true ) ]; end      
      def self.params()  [ spew( :params, true ) ];  end      
      def self.session() [ spew( :session, true ) ]; end
      def self.browser() [ spew( :browser, true ) ]; end      
      def self.headers() [ spew( :headers, true ) ]; end
      
      # Dump request time if any...
      def self.request_time?( args )
        args[:type] == Rackamole.perf ? ("%5.2f " % args[:request_time] ) : ''        
      end
      
      # Identify the type of alert...        
      def self.alert_type( args ) 
        case args[:type]
          when Rackamole.feature 
            "Feature"
          when Rackamole.perf
            "Performance"
          when Rackamole.fault
            "Fault"
        end
      end
  end
end