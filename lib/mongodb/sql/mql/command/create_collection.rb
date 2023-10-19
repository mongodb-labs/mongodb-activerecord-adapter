# frozen_string_literal: true

module MongoDB
  module SQL
    module MQL
      module Command
        class CreateCollection
          attr_reader :name, :columns

          def initialize(name, columns)
            @name, @columns = name, columns
          end

          def execute_on(database, session: nil, **)
            database[name[:value]].create(session: session, validator: validator)

            { rows: [] }
          end

          def to_s(*)
            "db.#{name[:value]}.create(validator: #{validator.to_json})"
          end

          private

          def validator
            { '$jsonSchema' => schema }
          end

          def schema
            {
              bsonType: 'object',
              properties: column_definitions
            }.tap do |schema|
              required = required_column_names
              schema[:required] = required if required.any?
            end
          end

          def required_column_names
            columns.select { |c| c.required? }.map { |c| c.mql_name }
          end

          def column_definitions
            columns.each_with_object({}) do |column, map|
              map[column.mql_name] = { bsonType: column.bson_type }
            end
          end
        end
      end
    end
  end
end
