# frozen_string_literal: true

module MongoDB
  module SQL
    module MQL
      module Command
        class Delete < Base
          attr_reader :collection_name, :filter

          def initialize(collection_name, filter)
            @collection_name = collection_name
            @filter = filter
          end

          def execute_on(database, session: nil, **)
            database[collection_name].delete_many({ '$expr' => filter }, session: session)
            { rows: [] } # returns nothing
          end
        end
      end
    end
  end
end
