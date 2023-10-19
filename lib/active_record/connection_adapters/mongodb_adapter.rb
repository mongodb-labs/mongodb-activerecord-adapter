# frozen_string_literal: true

require 'mongo'
require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mongodb/database_statements'
require 'active_record/connection_adapters/mongodb/schema_statements'

module ActiveRecord
  module ConnectionHandling
    def mongodb_adapter_class
      ConnectionAdapters::MongoDBAdapter
    end

    def mongodb_connection(config)
      mongodb_adapter_class.new(config)
    end
  end

  module ConnectionAdapters
    class MongoDBAdapter < AbstractAdapter
      ADAPTER_NAME = 'MongoDB'

      class <<self
        def new_client(config)
          hosts = [ *config[:host], *config[:hosts] ]
          hosts << '127.0.0.1:27017' if hosts.empty?
          Mongo::Client.new(hosts, database: config[:database])
        rescue Errno::ENOENT => error
          if error.message.include?('No such file or directory')
            raise ActiveRecord::NoDatabaseError
          else
            raise
          end
        end
      end

      include MongoDB::DatabaseStatements
      include MongoDB::SchemaStatements

      def purge_database!
        with_raw_connection do |conn|
          conn.database.collections.each do |collection|
            collection.drop
          end
        end
      end

      def supports_ddl_transactions?
        true
      end

      def supports_bulk_alter?
        true
      end

      # indexes specify their sort order for each field
      def supports_index_sort_order?
        true
      end

      def supports_explain?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_validate_constraints?
        false # but it probably could with json schema
      end

      def supports_insert_returning?
        false # but it probably could
      end

      def supports_insert_on_duplicate_update?
        true
      end

      def create_savepoint(name = current_savepoint_name)
        # do nothing; savepoints are ignored
      end

      def exec_rollback_to_savepoint(name = current_savepoint_name)
        #raise NotImplementedError, 'MongoDB does not support rolling back to savepoint'
      end

      def release_savepoint(name = current_savepoint_name)
        # do nothing
      end

      private

      def connect
        @raw_connection = self.class.new_client(@config)
      rescue ConnectionNotEstablished => ex
        raise ex.set_pool(@pool)
      end

      def reconnect
        @raw_connection&.close
        @raw_connection = nil
        connect
      end
    end
  end
end
