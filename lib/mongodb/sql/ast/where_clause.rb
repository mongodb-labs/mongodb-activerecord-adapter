# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class WhereClause
        include Dumpable
        dumpable :search_condition

        def initialize(search_condition)
          @search_condition = search_condition
        end

        def to_mql(context = {})
          { '$match' => { '$expr' => search_condition.to_mql(context.merge(expr: true)) } }
        end
      end
    end
  end
end
