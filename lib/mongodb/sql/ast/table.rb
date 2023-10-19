# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Table
        include Dumpable
        dumpable :name, :columns

        # @param [ identifier ] name
        # @param [ Array<SQL::AST::Column> ] columns
        def initialize(name, columns)
          @name = name
          @columns = columns
        end

        def to_mql(options = {})
          SQL::MQL::Command::CreateCollection.new(name, columns)
        end
      end
    end
  end
end
