require 'pony'
require 'erubis'

module Rackamole::Alert
  class Emole
    
    # retrieves erb template dir
    def self.template_root() @template_root ||= File.join( File.dirname(__FILE__), %w[templates] ); end
        
    # Send an email notification for particular moled feature. An email will
    # be sent based on the two configuration :emails and :mail_on defined on the
    # Rack::Mole component. These specify the to and from addresses and the conditions
    # that will trigger the email, currently :enabled and :features for the type of
    # moled features to track via email. The notification will be sent via Pony,
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
      @options = options
      opts     = options[:email]
      params   = opts.clone
      params[:to]      = opts[:to].join( ", " )
      params[:subject] = "RackAmole <#{alert_type( args )}> #{request_time?( args )} on #{args[:app_name]}.#{args[:host]} for user #{args[:user_name]}"
      
      @args = args
            
      tmpl     = File.join( template_root, %w[alert.erb] )
      template = Erubis::Eruby.new( IO.read( tmpl ), :trim => true )
            
      output        = template.result( binding )
      params[:body] = output

      Pony.mail( params )      
      output
    rescue => boom
      puts boom
      boom.backtrace.each { |l| puts l }
      logger.error( "Rackamole email alert failed with error `#{boom}" )
    end
            
    def self.section( title )
      buff = []
      # buff << "-"*80
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
        buff << spew( :url ) << spew( :path ) << spew( :status ) 
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
        args[:type] == Rackamole.perf ? ":#{args[:request_time]}" : ''        
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

      # # Dump args...
      # def self.dump( buff, env, level=0 )
      #   env.each_pair do |k,value|
      #     if value.respond_to?(:each_pair) 
      #       buff << "%s %-#{40-level}s" % ['  '*level,k]
      #       dump( buff, env[k], level+1 )
      #     elsif value.instance_of?(Array)
      #       buff << "%s %-#{40-level}s" % ['  '*level,k]
      #       value.each do |v| 
      #         buff << "%s %-#{40-(level+1)}s" % ['  '*(level+1),v]
      #       end
      #     else
      #       buff << "%s %-#{40-level}s %s" % [ '  '*level, k, value.inspect ]
      #     end        
      #   end
      # end
  end
end