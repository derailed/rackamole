module Rackamole
  module Store
    # Logger adapter. Stores mole information to a log file or dump it to stdout
    class Log
                  
      def initialize( file_name=$stdout )
        @logger = Rackamole::Logger.new( :log_file => file_name )
      end
      
      # Dump mole info to logger
      def mole( args )
        return if args.empty?
        
        if args[:stack]
          display_head "MOLED EXCEPTION" 
        elsif args[:performance]
          display_head "MOLED PERFORMANCE" 
        else
          display_head "MOLED FEATURE"
        end
        display_commons( args )          
      rescue => mole_boom
        log.error "MOLE STORE CRAPPED OUT -- #{mole_boom}"
        log.error mole_boom.backtrace.join( "\n   " )        
      end
         
      # =======================================================================
      private

        # dump moled info to log
        def display_commons( args )
          args.each do |k,v|
            display_info( k.to_s.capitalize, v.inspect )
          end
        end
        
        # retrieves logger instance
        def log
          @logger
        end
        
        # Console layout spacer
        def spacer() 20; end

        # Display mole type
        def display_head( msg )
          log.info "-"*100
          log.info msg
        end
        
        # Output formating...         
        def display_info( key, value )
          log.info "%-#{spacer}s : %s" % [key, value]
        end        
    end
  end
end