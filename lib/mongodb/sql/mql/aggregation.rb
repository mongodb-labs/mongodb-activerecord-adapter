# frozen_string_literal: true

require 'json'
require 'mongodb/sql/mql/base'

module MongoDB
  module SQL
    module MQL
      class Aggregation < Base
        attr_reader :target, :stages
        attr_reader :collection

        def initialize(target, stages)
          @target = target
          @stages = stages
          @collection = target.unqualified
        end

        def append(*list)
          Aggregation.new(target, ( stages + list ).compact)
        end

        def execute_on(database, session: nil, **)
          rows = database[collection].aggregate(stages, session: session).to_a

          # we need to expand embedded documents caused by joins, next.
          # we'll detect these by the presence of an _id field in the subdocument.
          #
          # FIXME: ideally we'd find a way to do this in the aggregation pipeline;
          # need to research that some more (something with $replaceRoot and $mergeObjects?)
          join_column_positions = detect_join_columns(rows.first)

          # if there are no join columns, return the keys and values directly
          if join_column_positions.empty?
            columns = rows.first&.keys || []
            return { columns: correct_id_column!(columns), rows: rows.map { |row| translate_values(row.values) }}
          end

          # otherwise, expand the joined columns. add a marker to the end of
          # join_column_positions to indicate the end of the list.
          join_column_positions << rows.first.count
          columns = column_headers(rows.first)

          {
            columns: correct_id_column!(columns),
            rows: expand_joined_columns(rows, join_column_positions)
          }
        end

        def to_s(mode = :js)
          if mode == :js
            "db.#{collection}.aggregate(#{stages.to_json})"
          else
            "database[#{collection.inspect}].aggregate(#{stages.inspect})"
          end
        end

        private

        def correct_id_column!(columns)
          columns.tap do
            pos = columns.index('_id')
            columns[pos] = 'id' if pos
          end
        end

        def detect_join_columns(archetype)
          [].tap do |positions|
            (archetype || {}).each_with_index do |(key, value), index|
              positions.push index if value.is_a?(Hash) && value.key?('_id')
            end
          end
        end

        def column_headers(archetype)
          [].tap do |headers|
            archetype.each do |name, value|
              if value.is_a?(Hash)
                headers.append(*value.keys.map { |n2| "#{name}_#{n2}" })
              else
                headers.push name
              end
            end
          end
        end

        def expand_joined_columns(rows, join_column_positions)
          rows.map do |row_hash|
            values = row_hash.values

            i = 0
            join_column_positions.flat_map do |j|
              [].tap do |row|
                while i < j # append all values from i...j
                  row.push(translate_value(values[i]))
                  i += 1
                end

                # expand and append all values from the hash at j
                if j < values.length
                  row.concat(translate_values(values[j].values))
                end

                i = j + 1
              end
            end
          end
        end

        def translate_values(list)
          list.map { |v| translate_value(v) }
        end

        def translate_value(value)
          if BSON::ObjectId === value
            value.to_s + '.$oid'
          else
            value
          end
        end
      end
    end
  end
end
