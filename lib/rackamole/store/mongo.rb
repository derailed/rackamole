require 'mongo'

include Mongo

# TODO !! Need to deal with auth
module Rackamole
  module Store
    # Mongo adapter. Stores mole info in a mongo database.
    # Two collections are available namely features and logs. Logs references
    # the features collection.
    class Mongo          
      
      attr_reader :connection
      
      def initialize( options={} )
        opts = default_options.merge( options )
        @connection = Connection.new( opts[:hostname], opts[:port] ).db( opts[:database] )  
      end
      
      # clear out db content
      def reset!
        features.clear
        logs.clear
      end
      
      # Dump mole info to logger
      def mole( args )
        return if args.empty?
        
        feature = find_or_create_feature( args )
        log_feature( feature, args )
      rescue => mole_boom
        $stderr.puts "MOLE STORE CRAPPED OUT -- #{mole_boom}"
        $stderr.puts mole_boom.backtrace.join( "\n   " )        
      end

      # Convenience to access mole features cltn
      def features
        @features ||= @connection['features']
      end
      
      # Convenience to access mole log cltn
      def logs
        @logs ||= @connection['logs']
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
        
        # retrieves a feature if exists or create a new one otherwise
        def find_or_create_feature( args )
          if args[:route_info]
            controller = args[:route_info][:controller]
            action     = args[:route_info][:action]
          end
          
          feature = find_feature( args[:app_name], args[:path], controller, action )
          
          # Got one
          return feature if feature

          # If not create a new feature          
          row = { :app_name => args[:app_name] }
          if controller and action
            row['controller'] = controller
            row['action']     = action
          else
            row['context'] = args[:path]
          end
          row['created_at'] = Time.now
          row['updated_at'] = Time.now
          features.insert( row )
        end
            
        # Attempt to find a mole feature
        def find_feature( app_name, path, controller, action )    
          conds = { 'app_name' => app_name }
        
          # For rails use controller/action  
          if controller and action
            conds['controller'] = controller
            conds['action']     = action
          # otherwise use path...
          else
            conds['context'] = path
          end
          features.find_one( conds )
        end
                
        # Insert a new feature in the db
        def log_feature( feature, args )
          type  = 'Feature'
          type  = 'Exception'   if args[:stack]
          type  = 'Performance' if args[:performance]
          
          row = {
            :type        => type,
            :feature     => ::DBRef.new( 'features', feature.instance_of?( ObjectID ) ? feature : feature['_id'] ),
            :created_at  => Time.now,
            :updated_at  => Time.now
          }
          
          skip_cols = [:app_name]
          args.each do |k,v|
            row[k] = v unless skip_cols.include?( k )
          end
          logs.insert( row )
        end
    end
  end
end