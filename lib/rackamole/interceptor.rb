module Rackamole
  module Interceptor
    
    # In order for the mole to trap framework exception, you must include
    # the interceptor in your application controller.
    # ie include Wackamole::Interceptor
    def self.included( base )
      base.send( :alias_method_chain, :rescue_action_in_public, :mole )
    end
    
    private
          
      # Instructs the mole to trap the framework exception
      def rescue_action_in_public_with_mole( exception )
        # Stuff the exception in the env for mole rack retrieval
        request.env['mole.exception'] = exception
        rescue_action_in_public_without_mole( exception )
      end
  end
end