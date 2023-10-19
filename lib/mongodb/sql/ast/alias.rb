# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Alias
        include Dumpable
        dumpable :reference, :ref_alias

        # ref_alias is a token, whose value is the alias for `ref` (an identifier)
        def initialize(ref, ref_alias)
          @reference, @ref_alias = ref, ref_alias
        end

        def aliased?
          !ref_alias.nil?
        end

        def constant?
          reference.is_a?(Hash)
        end

        def constant
          constant? && reference[:value]
        end

        def altname
          ref_alias ? ref_alias[:value] : reference.altname
        end

        def unqualified
          reference.unqualified
        end

        def full
          reference.full
        end

        def deref
          reference
        end

        def asterisk?
          false
        end

        def references?(identifier)
          reference.references?(identifier)
        end

        def to_mql(context = {})
          reference.to_mql(context).tap do |ident|
            if ref_alias
              aliases = context[:aliases] ||= {}
              # ref_alias, if present, is a token. The :value key holds the alias
              aliases[ref_alias[:value]] = ident
            end
          end
        end
      end
    end
  end
end
