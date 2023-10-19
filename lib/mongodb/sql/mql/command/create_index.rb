# frozen_string_literal: true

module MongoDB
  module SQL
    module MQL
      module Command
        class CreateIndex
          attr_reader :name, :collection_name, :columns, :unique

          def initialize(name, collection_name, columns, unique)
            @name, @collection_name, @columns = name, collection_name, columns
            @unique = unique
          end

          def execute_on(database, session: nil, **)
            database[name[:value]].indexes.create_one(keys, unique: unique, comment: name, session: session)
            { rows: [] }
          end

          def to_s(*)
            "database['#{name[:value]}'].indexes.create_one(#{keys.inspect}, unique: #{unique.inspect}, comment: #{name.inspect})"
          end

          private

          def keys
            columns.each_with_object({}) { |c, map| map[c[:value]] = 1 }
          end
        end
      end
    end
  end
end
