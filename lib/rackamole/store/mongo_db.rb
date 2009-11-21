require 'mongo'

# TODO !! Need to deal with auth
# BOZO !! Deal with indexes here ?
module Rackamole
  module Store
    # Mongo adapter. Stores mole info in a mongo database.
    class MongoDb
      
      attr_reader :database, :logs, :features
      
      # Defines the various feature types
      FEATURE     = 0
      PERFORMANCE = 1
      EXCEPTION   = 2
      
      def initialize( options={} )
        opts = default_options.merge( options )
        init_mongo( opts )
      end
      
      # clear out db content ( used in testing... )
      def reset!
        logs.remove
        features.remove
      end
      
      # Dump mole info to logger
      def mole( arguments )
        return if arguments.empty?       
        
        # get a dup of the args since will mock with the original
        args = arguments.clone

        # dump request info to mongo
        save_log( save_feature( args ), args )
      rescue => mole_boom
        $stderr.puts "MOLE STORE CRAPPED OUT -- #{mole_boom}"
        $stderr.puts mole_boom.backtrace.join( "\n   " )        
      end

      # =======================================================================
      private

        def init_mongo( opts )
          @connection = Mongo::Connection.new( opts[:host], opts[:port], :logger => opts[:logger] )
          @database   = @connection.db( opts[:database] )
          @features   = database.collection( 'features' )
          @logs       = database.collection( 'logs' )
        end
                
        # Set up mongo default options ie localhost host, default mongo port and
        # the database being mole_mdb      
        def default_options
          {
             :host     => 'localhost',
             :port     => 27017,
             :database => 'mole_mdb'
          }
        end
        
        # Find or create a mole feature
        def save_feature( args )
          app_name    = args.delete( :app_name )
          route_info  = args.delete( :route_info )
          environment = args.delete( :environment )
        
          row = { min_field(:app_name) => app_name, min_field(:env) => environment }
          if route_info
            row[min_field(:controller)] = route_info[:controller]
            row[min_field(:action)]     = route_info[:action]
          else
            row[min_field(:context)] = args.delete( :path )
          end
          
          feature = features.find_one( row )
          return feature if feature
          
          id = features.save( row )
          features.find_one( id )
        end
                                    
        # Insert a new feature in the db
        def save_log( feature, args )               
          type  = FEATURE
          type  = EXCEPTION   if args[:stack]
          type  = PERFORMANCE if args.delete(:performance)
          
          # BOZO !! to reduce collection space...
          # Using cryptic key to reduce storage needs.
          # Also narrowing date/time to ints
          now = Time.now
          row = {
            min_field( :type )       => type,
            min_field( :feature_id ) => feature['_id'].to_s,
            min_field( :date_id )    => ("%4d%02d%02d" %[now.year, now.month, now.day]).to_i,
            min_field( :time_id )    => ("%02d%02d%02d" %[now.hour, now.min, now.sec] ).to_i
          }
          
          args.each do |k,v|
            row[min_field(k)] = v if v
          end
          logs.save( row )
        end
        
        # For storage reason minify the json to save space...
        def min_field( field )
          field_map[field] || field
        end
            
        # Normalize all accessors to 3 chars. 
        def field_map
          @field_map ||= {
            :app_name     => :app,
            :context      => :ctx,
            :controller   => :ctl,
            :action       => :act,
            :type         => :typ,
            :feature_id   => :fid,
            :date_id      => :did,
            :time_id      => :tid,
            :user_id      => :uid,
            :user_name    => :una,
            :browser      => :bro,            
            :host         => :hos,
            :software     => :sof,
            :request_time => :rti,
            :performance  => :per,
            :method       => :met,
            :path         => :pat,
            :session      => :ses,
            :params       => :par,
            :ruby_version => :ver,
            :stack        => :sta
          }
        end      
    end
  end
end