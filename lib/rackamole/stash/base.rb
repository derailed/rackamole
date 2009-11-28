module Rackamole::Stash
  # Stash mole information into the env. These objects are meant to track 
  # instances of a similar event occurring in the application so that alerts
  # are kept under control when shit hits the fan...
  class Base    
    attr_reader :path, :timestamp, :count

    # =======================================================================--
    protected
        
      def initialize( path, timestamp )
        @path      = path
        @count     = 1
        @timestamp = timestamp
      end

    public
        
      # Update count and timestamp
      def update( timestamp )
        @timestamp  = timestamp
        @count     += 1
      end
  end
end