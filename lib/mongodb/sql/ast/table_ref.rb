# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class TableRef
        include Dumpable
        dumpable :target, :joins

        def initialize(target, joins)
          @target, @joins = target, joins
        end

        def to_mql(context = {})
          # so joins know the primary collection
          context = context.merge(primary: target)
          SQL::MQL::Aggregation.new(target, joins.flat_map { |j| j.to_mql(context) })
        end
      end
    end
  end
end
