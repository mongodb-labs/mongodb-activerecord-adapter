# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Delete
        include Dumpable
        dumpable :target, :condition

        def initialize(target, condition)
          @target, @condition = target, condition
        end

        def to_mql(context = {})
          target_name = target[:value]
          filter = condition.to_mql(context.merge(expr: true, primary: SQL::AST::Identifier.new([target])))
          SQL::MQL::Command::Delete.new(target_name, filter)
        end
      end
    end
  end
end
