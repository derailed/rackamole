module Rackamole::Stash
  # Caches perfs and faults. If either has been seen before update their 
  # respective counts. This is used by the mole to track if a perf or exception
  # was previously recorded.
  class Collector
    
    attr_reader :app_id
    
    NEVER = -1
    
    def initialize( app_name, environment, expiration=24*60*60 )
      @expiration = expiration
      @app_id     = app_name + "_" + environment.to_s
      @faults     = {}
      @perfs      = {}
    end

    # Remove all entries that have expired
    def expire!
      expire_faults!
      expire_perfs!
    end
    
    # Delete all faults older than expiration
    def expire_faults!
      now = Time.now
      faults.each_pair do |stack, fault|
        if (now - fault.timestamp) >= expiration
          faults.delete( stack )
        end
      end
    end
    
    # Delete all perfs older than expiration
    def expire_perfs!
      now = Time.now.utc
      perfs.each_pair do |path, perf|
        if (now - perf.timestamp) >= expiration
          perfs.delete( path )
        end
      end
    end
    
    # Log or update fault if found...
    # Returns true if updated or false if created
    def stash_fault( path, stack, timestamp )
      fault = find_fault( path, stack )
      if fault
        fault.update( timestamp )
        return true
      end
      fault = create_fault( path, stack, timestamp )
      faults[stack] = fault
      false
    end

    # Log or update performance issue if found...
    # Returns true if updated or false if created    
    def stash_perf( path, elapsed, timestamp )
      perf = find_perf( path )
      if perf
        perf.update( timestamp )
        return true
      end
      perf = create_perf( path, elapsed, timestamp )
      perfs[path] = perf
      false
    end
        
    # =========================================================================
    private    
    
      attr_reader :faults, :perfs, :expiration
       
      def create_fault( path, stack, timestamp )
        faults[stack] = Rackamole::Stash::Fault.new( path, stack, timestamp )
      end

      def create_perf( path, elapsed, timestamp )
        perfs[path] = Rackamole::Stash::Perf.new( path, elapsed, timestamp )
      end

      # Check if we've seen a similar fault on this application
      def find_fault( path, stack )
        faults[stack]
      end

      # Check if we've seen this perf issue on this application
      def find_perf( path )
        perfs[path]
      end       
  end
end