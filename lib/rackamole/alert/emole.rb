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
    # options    :: Hash minimaly containing :from for the from address. Must be a valid domain.
    #            :: And a :to, n array of email addresses for recipients to be notified.
    # args       :: The gathered information from the mole.
    #
    def self.deliver_alert( logger, options, args )
      params = options.clone
      params[:to]      = options[:to].join( ", " )
      params[:subject] = "[M()le] (#{alert_type( args )}#{request_time?( args )}) -#{args[:app_name]}@#{args[:host]}- for user #{args[:user_name]}"
      
      content = []
      dump( content, args, 0 )
      content = content.join( "\n" )
      
      tmpl     = File.join( template_root, %w[alert.erb] )
      template = Erubis::Eruby.new( IO.read( tmpl ), :trim => true )
            
      output        = template.result( binding )
      params[:body] = output

      Pony.mail( params )      
      output
    rescue => boom
      logger.error( "Rackamole email alert failed with error `#{boom}" )
    end
            
    # =========================================================================               
    private
           
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

      # Dump args...
      def self.dump( buff, env, level=0 )
        env.each_pair do |k,value|
          if value.respond_to?(:each_pair) 
            buff << "%s %-#{40-level}s" % ['  '*level,k]
            dump( buff, env[k], level+1 )
          elsif value.instance_of?(Array)
            buff << "%s %-#{40-level}s" % ['  '*level,k]
            value.each do |v| 
              buff << "%s %-#{40-(level+1)}s" % ['  '*(level+1),v]
            end
          else
            buff << "%s %-#{40-level}s %s" % [ '  '*level, k, value.inspect ]
          end        
        end
      end
  end
end