require 'action_mailer'

module Rackamole::Alert
  class Emole < ActionMailer::Base        
    self.template_root = File.join( File.dirname(__FILE__), %w[templates] )
        
    # Send an email notification for particular moled feature. An email will
    # be sent based on the two configuration :emails and :mail_on defined on the
    # Rack::Mole component. These specify the to and from addresses and the conditions
    # that will trigger the email, currently :enabled and :features for the type of
    # moled features to track via email. The notification will be sent via actionmailer,
    # so you will need to make sure it is properly configured for your domain.
    # NOTE: This is just a notification mechanism. All moled event will be either logged 
    # or persisted in the db regardless.
    #
    # === Parameters:
    # from       :: The from address address. Must be a valid domain.
    # recipients :: An array of email addresses for recipients to be notified.
    # args       :: The gathered information from the mole.
    #
    def alert( from, recipients, args )
      buff = []
      
      dump( buff, args, 0 )
      
      from        from
      recipients  recipients
      subject     "[M()le] (#{alert_type( args )}#{request_time?( args )}) -#{args[:app_name]}@#{args[:host]}- for user #{args[:user_name]}"        
      body        :args  => args,
                  :dump  => buff.join( "\n" )
    end
        
    # =========================================================================               
    private
           
      # Dump request time if any...
      def request_time?( args )
        args[:type] == Rackamole.perf ? ":#{args[:request_time]}" : ''        
      end
      
      # Identify the type of alert...        
      def alert_type( args ) 
        case args[:type]
          when Rackamole.feature : "Feature"
          when Rackamole.perf    : "Performance"
          when Rackamole.fault   : "Fault"
        end
      end

      # Dump args...
      def dump( buff, env, level=0 )
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