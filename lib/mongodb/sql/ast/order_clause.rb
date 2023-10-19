# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class OrderClause
        include Dumpable
        dumpable :sort_specifications

        ORDER_MAPPING = {
          asc: 1,
          desc: -1
        }

        def initialize(sort_specifications)
          @sort_specifications = sort_specifications
        end

        def to_mql(context = {})
          specs = sort_specifications.each_with_object({}) { |spec, map|
            map[spec[:key].to_mql(context)] = ORDER_MAPPING.fetch(spec[:order][:token]) }

          { '$sort' => specs }
        end
      end
    end
  end
end
