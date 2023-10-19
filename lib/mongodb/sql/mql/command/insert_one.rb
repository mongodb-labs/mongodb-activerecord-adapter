# frozen_string_literal: true

module MongoDB
  module SQL
    module MQL
      module Command
        class InsertOne < Base
          attr_reader :collection_name, :properties

          def initialize(collection_name, properties)
            @collection_name = collection_name
            @properties = properties
          end

          def execute_on(database, session: nil, **)
            type_cast_via(database, properties)

            result = database[collection_name].insert_one(properties.compact, session: session)

            {
              columns: [ 'id' ],
              rows: [ [ result.inserted_id.to_s + '.$oid' ] ]
            }
          end

          def to_s(*)
            "db.#{collection_name}.insert_one(#{properties.to_json})"
          end
        end
      end
    end
  end
end
