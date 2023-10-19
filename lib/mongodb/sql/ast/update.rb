# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Update
        include Dumpable
        dumpable :target, :set_list, :condition

        def initialize(target, set_list, condition)
          @target, @set_list, @condition = target, set_list, condition
        end

        def to_mql(context = {})
          target_name = target[:value]
          updates = set_list.each_with_object({}) do |pair, map|
            map[pair[:column][:value]] = pair[:value].to_mql(context)
          end
          filter = condition.to_mql(context.merge(expr: true, primary: SQL::AST::Identifier.new([target])))
          SQL::MQL::Command::Update.new(target_name, filter, updates)
        end
      end
    end
  end
end
