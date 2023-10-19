# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Variable
        include Dumpable
        dumpable :value, :position

        def initialize(value, position)
          @value = value
          @position = position
        end

        def flatten(acc)
          acc[:children].push self
        end

        def to_mql(context = {})
          variables = context[:variables] || []
          if position >= variables.length
            raise "bind parameter at #{position} out of bounds"
          end

          var = variables[position]

          if var.is_a?(String) && var.end_with?('.$oid')
            BSON::ObjectId.from_string(var.split('.').first)
          else
            var
          end
        end
      end
    end
  end
end
