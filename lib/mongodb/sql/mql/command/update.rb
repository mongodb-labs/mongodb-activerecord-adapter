# frozen_string_literal: true

module MongoDB
  module SQL
    module MQL
      module Command
        class Update < Base
          attr_reader :collection_name, :filter, :updates

          def initialize(collection_name, filter, updates)
            @collection_name = collection_name
            @filter = filter
            @updates = updates
          end

          def execute_on(database, session: nil, **)
            type_cast_via(database, updates)
            database[collection_name].update_many({ '$expr' => filter }, { '$set' => updates }, session: session)
            { rows: [] } # returns nothing
          end
        end
      end
    end
  end
end
