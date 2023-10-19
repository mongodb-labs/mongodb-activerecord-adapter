# frozen_string_literal: true

require 'date'

module MongoDB
  module SQL
    module MQL
      class Base
        private

        # TODO: cache this somehow, so it isn't queried every single
        # time there's an insert
        def type_cast_via(database, attrs)
          info = database.list_collections(filter: { name: collection_name }).first
          return nil unless info

          schema = info['options']['validator']['$jsonSchema']
          props = schema['properties']

          props.each do |key, info|
            next unless attrs.key?(key)
            attrs[key] = type_cast(attrs[key], info)
          end
        end

        def type_cast(value, schema)
          return nil if value.nil?

          method = :"type_cast_as_#{schema['bsonType']}"
          if respond_to?(method, true)
            send(method, value)
          else
            value
          end
        end

        def type_cast_as_objectId(value)
          case value
          when Hash then value['$oid']
          else value
          end
        end

        def type_cast_as_long(value)
          BSON::Int64.new(value)
        end

        def type_cast_as_date(value)
          case value
          when String then DateTime.parse(value)
          else value
          end
        end

        def type_cast_as_string(value)
          case value
          when Hash then value.to_json
          when String then
            if value.end_with?('.$oid')
              BSON::ObjectId.from_string(value.split('.').first)
            else
              value
            end
          else value.to_s
          end
        end
      end
    end
  end
end
