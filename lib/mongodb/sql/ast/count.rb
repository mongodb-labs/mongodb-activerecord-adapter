# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Count
        include Dumpable
        dumpable :ident, :distinct

        def initialize(ident, distinct)
          @ident = ident
          @distinct = distinct

          puts '*** COUNT DISTINCT is not yet supported ***' if distinct
        end

        def asterisk?
          false
        end

        def aliased?
          false
        end

        def constant?
          false
        end

        def unqualified
          "COUNT(#{ident.full})"
        end
        alias full unqualified

        def qualified?
          false
        end

        def references?(*)
          false
        end

        def deref
          self
        end
      end
    end
  end
end
