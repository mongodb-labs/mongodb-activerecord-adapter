# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Constant
        include Dumpable
        dumpable :value

        def initialize(value)
          @value = value
        end

        def flatten(acc)
          acc[:children].push self
        end

        def to_mql(context = {})
          value
        end
      end
    end
  end
end
