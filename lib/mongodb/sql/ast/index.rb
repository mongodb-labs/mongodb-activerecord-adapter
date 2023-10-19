# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Index
        include Dumpable
        dumpable :name, :table_name, :columns, :unique

        # @param [ identifier ] name the index name
        # @param [ identifier ] table_name the table name
        # @param [ Array<identifier> ] columns
        # @param [ true | false ] unique
        def initialize(name, table_name, columns, unique: false)
          @name = name
          @table_name = table_name
          @columns = columns
          @unique = unique
        end

        def to_mql(options = {})
          SQL::MQL::Command::CreateIndex.new(name, table_name, columns, unique)
        end
      end
    end
  end
end
