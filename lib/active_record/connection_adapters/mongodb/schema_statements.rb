# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MongoDB
      module SchemaStatements
        def tables
          with_raw_connection do |conn|
            conn.database.list_collections(name_only: true).map { |c| c['name'] }
          end
        end

        def views
          []
        end

        def primary_keys(table_name)
          %w[ id ]
        end

        def column_definitions(table_name)
          with_raw_connection do |conn|
            info = conn.database.list_collections(filter: { name: table_name }).first
            raise "no such collection #{table_name.inspect}" if info.nil?

            schema = info['options']['validator']['$jsonSchema']
            required = schema['required']
            properties = schema['properties']

            properties.map do |(key, prop)|
              {
                'name' => key == '_id' ? 'id' : key,
                'required' => required.include?(key),
                **prop
              }
            end
          end
        end

        private

        BSON_TYPE_MAP = {
          'objectId' => 'primary_key',
          'long' => 'integer',
          'date' => 'datetime',
        }.freeze

        def new_column_from_field(table_name, field, _definitions)
          type = SqlTypeMetadata.new(
            sql_type: BSON_TYPE_MAP.fetch(field['bsonType'], field['bsonType']),
            type: field['bsonType'])

          Column.new(
            field['name'],
            nil, # default
            type,
            !field['required'] # nullable
          )
        end
      end
    end
  end
end
