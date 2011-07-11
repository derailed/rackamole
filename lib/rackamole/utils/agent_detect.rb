# This agent business is a cluster fuck. Won't even pretend detection will 
# be accurate. But at least an honest try...
# BOZO !! Need to handle iphone, android, etc...
module Rackamole::Utils
  class AgentDetect
    
    # browsers...
    def self.browsers() %w[Opera Firefox Chrome Safari MSIE]; end
    
    # Parses user agent to extract browser and machine info
    def self.parse( agent )
      browsers.each do |browser|
        return extract( agent, browser ) if check?( agent, browser )
      end
      defaults
    end
    
    # =========================================================================
    private
    
      # Check for known browsers
      def self.check?( agent, browser )
        agent.match( /#{browser}/ )
      end
      
      # Pre populate info hash
      def self.defaults
        info = { :browser => {}, :machine => {} }
        %w[name version].each { |t| info[:browser][t.to_sym] = "N/A" }
        %w[platform os version local].each { |t| info[:machine][t.to_sym] = "N/A" }
        info
      end        

      # Extract machine and browser info
      def self.extract( agent, browser )
        @info = defaults
        begin
          extract_browser( agent, browser )
          extract_platform( agent )    
        rescue => boom
          $stderr.puts "Unable to parse user agent `#{agent}"
          $stderr.puts boom
          boom.backtrace.each { |l| $stderr.puts l }
        end
        @info
      end

      # Extract browser and version      
      def self.extract_browser( agent, browser )
        @info[:browser][:name] = browser
        match = agent.match( /#{browser}[\/|\s]([\d|\.?]+)/ )        
        @info[:browser][:version] = match[1] if match and match[1]
      end
      
      # Extracts machine info
      def self.extract_platform( agent )
        match = agent.match( /\((.*)\)/ )
        return unless match and match[1]
        
        machine_info = match[1]
        tokens       = machine_info.split( ";" )
        unless tokens.empty?
          platform = tokens.shift.strip
          @info[:machine][:platform] = platform
          
          os_info = tokens.shift
          os_info = tokens.shift if os_info && os_info.match( /[MSIE|U]/ )
          os = os_info.match( /(.+)\s([\w\d|\.]+)/ ) if os_info
          if os
            @info[:machine][:os]      = os[1].strip if os[1]
            @info[:machine][:version] = os[2].strip if os[2]
          end
        end
      end
  end
end