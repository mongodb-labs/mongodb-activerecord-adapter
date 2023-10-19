# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Insert
        include Dumpable
        dumpable :target, :columns, :values

        def initialize(target, columns, values)
          @target, @columns, @values = target, columns, values
        end

        def to_mql(context = {})
          values = @values.map { |v| v.to_mql(context) }
          properties = Hash[columns.zip(values).map { |c, v| [ c[:value], v ] }]
          SQL::MQL::Command::InsertOne.new(target[:value], properties)
        end
      end
    end
  end
end
