module Rackamole::Stash
  class Perf < Rackamole::Stash::Base
    attr_reader :elapsed
    
    def initialize( path, elapsed, timestamp )
      super( path, timestamp )
      @elapsed   = elapsed
    end    
  end
end