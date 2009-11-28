module Rackamole::Stash
  class Fault < Rackamole::Stash::Base
    attr_reader :stack
    
    def initialize( path, stack, timestamp )
      super( path, timestamp )
      @stack = stack
    end    
  end
end