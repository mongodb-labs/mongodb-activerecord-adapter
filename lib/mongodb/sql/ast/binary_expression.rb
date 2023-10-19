# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class BinaryExpression
        include Dumpable
        dumpable :op, :left, :right

        MQL_OPERATOR_MAPPING = {
          '=' => '$eq',
          :is => '$eq',
          '<' => '$lt',
          '>' => '$gt',
          '<=' => '$lte',
          '>=' => '$gte',
          '<>' => '$ne',
          '!=' => '$ne',
        }

        def initialize(left, op, right)
          @left, @op, @right = left, op, right
        end

        # turn the tree representation into a set of nested arrays. it does this
        # by hoisting children that have the same operator as the parent.
        def flatten(acc = { op: op, children: [] })
          acc.tap do
            if op != acc[:op]
              sub = { op: op, children: [] }
              acc[:children].push(sub)
              acc = sub
            end

            left.flatten(acc)
            right.flatten(acc)
          end
        end

        def to_mql(context = {})
          operation_to_mql(flatten, context)
        end

        private

        # if :let key is present, build the :let hash as we go.
        #
        # LEAF NODES:
        #  - constant:
        #       emit literally
        #  - variable:
        #       replace from the bind variables and emit literally
        #  - identifier :
        #       if :expr:
        #         if not qualified: raise an exception
        #         if qualified with the current collection:
        #            - no let assignment needed
        #            - variable name = '$field' (remove qualification)
        #         if qualified with the primary collection:
        #            - add variable to :let ('primary_field' => '$field')
        #            - variable name = '$$primary_field'
        #         if qualified with a different collection (we'll assume the other
        #         collection has already been joined previously):
        #            - add variable to :let ('other_field' => '$other.field')
        #            - variable name = '$$other_field'
        #       if not :expr:
        #         if qualified
        #            if prefix is the current collection:
        #               emit identifier.last
        def operation_to_mql(operation, context)
          if operation[:op] == :and || operation[:op] == :or
            { "$#{operation[:op]}" => operation[:children].map { |child| operation_to_mql(child, context) } }
          else
            mql_op = MQL_OPERATOR_MAPPING.fetch(operation[:op])
            left = operation[:children][0]
            right = operation[:children][1]

            lmql = left.to_mql(context)
            rmql = right.to_mql(context)

            if mql_op == '$eq' && (lmql.nil? || rmql.nil?)
              lmql, rmql = rmql, lmql if lmql.nil?
              mql_op = '$lte'
            end

            { mql_op => [ lmql, rmql ] }
          end
        end
      end
    end
  end
end
