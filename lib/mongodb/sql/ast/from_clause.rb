# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class FromClause
        include Dumpable
        dumpable :list

        def initialize(list)
          @list = list
        end

        def to_mql(context = {})
          # for now let's simply disallow implicit joins
          if list.length > 1
            # implicit join (e.g. "FROM t1, t2 WHERE t1.key = t2.foreign_key")
            raise NotImplementedError, 'implicit joins are not currently supported'
          end

          # explicit join (e.g. "FROM t1 JOIN t2 ON t1.key = t2.foreign_key")
          #   INNER, OUTER, LEFT, RIGHT

          list.first.to_mql(context)
        end
      end
    end
  end
end
