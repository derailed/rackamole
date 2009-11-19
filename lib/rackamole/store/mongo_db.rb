require 'mongo'

include Mongo

# TODO !! Need to deal with auth
module Rackamole
  module Store
    # Mongo adapter. Stores mole info in a mongo database.
    class MongoDb
            
      def initialize( options={} )
        opts = default_options.merge( options )
        MongoMapper.connection = Connection.new( opts[:host], opts[:port], :logger => opts[:logger] )
        MongoMapper.database   = opts[:database]
      end
      
      # clear out db content ( used in testing... )
      def reset!
        Rackamole::Mongo::Feature.delete_all
        Rackamole::Mongo::Log.delete_all
      end
      
      # Dump mole info to logger
      def mole( arguments )
        return if arguments.empty?       
        args = arguments.clone
        
        app_name = args.delete( :app_name )
        
        if args[:route_info]
          controller = args[:route_info][:controller]
          action     = args[:route_info][:action]
          feature    = Rackamole::Mongo::Feature.find_or_create_by_app_name_and_controller_and_action( app_name, controller, action )
        else
          context    = args[:path]
          feature    = Rackamole::Mongo::Feature.find_or_create_by_app_name_and_context( app_name, context )          
        end
        log_feature( feature, args )
      rescue => mole_boom
        $stderr.puts "MOLE STORE CRAPPED OUT -- #{mole_boom}"
        $stderr.puts mole_boom.backtrace.join( "\n   " )        
      end

      # =======================================================================
      private
        
        # Set up mongo default options ie localhost host, default mongo port and
        # the database being mole_mdb      
        def default_options
          {
             :host     => 'localhost',
             :port     => 27017,
             :database => 'mole_mdb'
          }
        end
                                    
        # Insert a new feature in the db
        def log_feature( feature, args )
          type  = 'Feature'
          type  = 'Exception'   if args[:stack]
          type  = 'Performance' if args[:performance]
          
          attrs = {
            :type        => type,
            :feature     => feature,
            :created_at  => Time.now,
            :updated_at  => Time.now
          }
          
          args.each do |k,v|
            attrs[k] = v
          end
          Rackamole::Mongo::Log.create!( attrs )
        end
    end
  end
end