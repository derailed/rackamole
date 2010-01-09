module Rackamole::Store
  class Log
            
    # Stores mole information to a log file or dump it to the console. All
    # available mole info will dumped to the logger.
    #
    # === Params:
    # file_name :: Specifies a file to send the logs to. By default mole info
    # will be sent out to stdout.
    def initialize( file_name=$stdout )
      @logger = Rackamole::Logger.new( :log_file => file_name )
    end
    
    # Dump mole info to logger
    #
    # === Params:
    # attrs :: The available moled information for a given feature
    def mole( attrs )
      return if attrs.empty?
              
      display_head( attrs )
      display_commons( attrs )          
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
      def display_head( args )
        log.info "-"*100
        log.info case args[:type]
          when Rackamole.feature 
            "FEATURE m()le"
          when Rackamole.fault
            "FAULT m()le"
          when Rackamole.perf
            "PERFORMANCE m()le"
        end
      end
      
      # Output formating...         
      def display_info( key, value )
        log.info "%-#{spacer}s : %s" % [key, value]
      end        
  end
end