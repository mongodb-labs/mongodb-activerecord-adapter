# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Column
        include Dumpable
        dumpable :name, :type, :constraints

        # @param [ identifier ] name
        # @param [ identifier ] type
        # @param [ Array ] constraints
        def initialize(name, type, constraints)
          @name = name
          @type = type
          @constraints = constraints
        end

        def required?
          constraints.any? { |c| c == :not_null }
        end

        TYPE_MAP = {
          'primary_key' => 'objectId',
          'datetime'    => 'date',
          'integer'     => 'long',
          'text'        => 'string',
          'bigint'      => 'long',
        }.freeze

        def bson_type
          TYPE_MAP.fetch(type[:value], type[:value])
        end

        def sql_name
          name[:value]
        end

        def mql_name
          sql_name == 'id' ? '_id' : sql_name
        end
      end
    end
  end
end
