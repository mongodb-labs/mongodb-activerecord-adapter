# frozen_string_literal: true

require 'mongodb/sql/parser'
require 'mongodb/sql/tokenizer'

module ActiveRecord
  module ConnectionAdapters
    module MongoDB
      module DatabaseStatements
        READ_QUERY = AbstractAdapter.build_read_query_regexp # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        def return_value_after_insert?(column) # :nodoc:
          column.name == 'id'
        end

        def explain(arel, binds = [], options = []) # :nodoc:
          raise NotImplementedError
        end

        def internal_exec_query(sql, name = "SQL", binds = [], prepare: false, async: false) # :nodoc:
          command = sql_to_command(sql, binds)
          execute_command(command)
        end

        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          command = sql_to_command(sql)
          execute_command(command)
        end

        # === TRANSACTIONS

        def begin_isolated_db_transaction(isolation)
          raise NotImplementedError
        end

        def begin_db_transaction
          with_raw_connection do |conn|
            start_session_for(conn).start_transaction
          end
        end

        def commit_db_transaction
          with_raw_connection do |conn|
            session_mapping[conn].commit_transaction
            clear_session_for(conn)
          end
        end

        def exec_rollback_db_transaction
          with_raw_connection do |conn|
            session_mapping[conn].abort_transaction
            clear_session_for(conn)
          end
        end

        def exec_restart_db_transaction()
          raise NotImplementedError
        end

        private

        def execute_command(command)
          with_raw_connection do |conn|
            result = command.execute_on(conn.database, session: session_mapping[conn])
            ActiveRecord::Result.new(result[:columns] || [], result[:rows] || [])
          end
        end

        def sql_to_command(sql, binds = [])
          tokens = ::MongoDB::SQL::Tokenizer.new(sql)
          ast = ::MongoDB::SQL::Parser.new.parse_statement(tokens)
          values = binds.map { |b| b.respond_to?(:value) ? b.value : b }
          ast.to_mql(variables: values)
        end

        def session_mapping
          @session_mapping ||= {}
        end

        def clear_session_for(connection)
          session_mapping[connection]&.end_session
          session_mapping.delete(connection)
        end

        def start_session_for(connection)
          session_mapping[connection] ||= connection.start_session
        end
      end
    end
  end
end
