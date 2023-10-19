# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class TableExpr
        include Dumpable
        dumpable :from, :where, :order, :limit

        def initialize(from, where, order, limit)
          @from, @where, @order, @limit =
            from, where, order, limit
        end

        def to_mql(context = {})
          command = from.to_mql(context)

          # for processing qualified identifiers
          context = context.merge(primary: command.target)

          match = where.to_mql(context) if where
          sort  = order.to_mql(context) if order
          limit = self.limit.to_mql(context) if self.limit

          command.append(match, sort, limit)
        end
      end
    end
  end
end
