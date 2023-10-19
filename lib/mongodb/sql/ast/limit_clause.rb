# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class LimitClause
        include Dumpable
        dumpable :count

        def initialize(count)
          @count = count
        end

        def to_mql(context = {})
          { '$limit' => count.to_mql(context) }
        end
      end
    end
  end
end
