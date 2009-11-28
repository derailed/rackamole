require 'mongo'

# TODO !! Need to deal with auth
# BOZO !! Deal with indexes here ?
module Rackamole
  module Store
    # Mongo adapter. Stores mole info to a mongo database.
    class MongoDb
      
      attr_reader :database, :logs, :features #:nodoc:
            
      # Initializes the mongo db store. MongoDb can be used as a persitent store for
      # mole information. This is a preferred store for the mole as it will allow you
      # to gather up reports based on application usage, perf or faults...
      #
      # Setup rackamole to use the mongodb store as follows:
      #
      #   config.middleware.use Rack::Mole, { :store => Rackamole::Store::MongoDb.new }
      #
      # === Options
      #
      # :host     :: The name of the host running the mongo server. Default: localhost
      # :port     :: The port for the mongo server instance. Default: 27017
      # :database :: The name of the mole databaase. Default: mole_mdb
      #
      def initialize( options={} )
        opts = default_options.merge( options )
        validate_options( opts )
        init_mongo( opts )
      end
            
      # Dump mole info to a mongo database. There are actually 2 collections
      # for mole information. Namely features and logs. The features collection hold
      # application and feature information and is referenced in the mole log. The logs
      # collections holds all information that was gathered during the request
      # such as user, params, session, request time, etc...
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
        
        # Clear out mole database content ( Careful there - testing only! )
        def reset!
          logs.remove
          features.remove
        end

        def init_mongo( opts )
          @connection = Mongo::Connection.new( opts[:host], opts[:port], :logger => opts[:logger] )
          @database   = @connection.db( opts[:database] )
          @features   = database.collection( 'features' )
          @logs       = database.collection( 'logs' )
        end

        # Validates option hash.
        def validate_options( opts )     
          %w[host port database].each do |option|
            unless opts[option.to_sym]
              raise "[MOle] Mongo store configuration error -- You must specify a value for option `:#{option}" 
            end
          end
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
        
          row = { min_field(:app_name) => app_name, min_field(:env) => environment.to_s }
          if route_info
            row[min_field(:controller)] = route_info[:controller]
            row[min_field(:action)]     = route_info[:action]
          else
            row[min_field(:context)] = args.delete( :path )
          end
          
          feature = features.find_one( row, :fields => ['_id'] )
          return feature['_id'] if feature

          row[min_field(:created_at)] = args[:created_at]
                    
          features.save( row )
        end
                                    
        # Insert a new feature in the db
        # NOTE : Using min key to reduce storage needs. I know not that great for higher level api's :-(
        # also saving date and time as ints. same deal...
        def save_log( feature_id, args )
          now = args.delete( :created_at )
          row = {
            min_field( :type )       => args[:type],
            min_field( :feature_id ) => feature_id.to_s,
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
            :env          => :env,
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
            :fault        => :msg,
            :stack        => :sta,
            :created_at   => :cro
          }
        end      
    end
  end
end