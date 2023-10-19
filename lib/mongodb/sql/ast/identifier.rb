# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Identifier
        include Dumpable
        dumpable :path

        def initialize(path)
          @path = path
        end

        def constant?
          false
        end

        def asterisk?
          path.last[:token] == '*'
        end

        def qualified?
          path.length > 1
        end

        def aliased?
          false
        end

        def joined(delim = '.')
          path.map { |i| i[:value] }.join(delim)
        end
        alias full joined

        def prefix?(str)
          path[0..-2].any? { |part| part[:value] == str }
        end

        def last
          path.last[:value]
        end
        alias unqualified last

        def deref
          self
        end

        # make this quack like an Alias
        def altname
          last
        end

        def flatten(acc)
          acc[:children].push(self)
        end

        # Queries whether this identifier references the given identifier, either
        # via an alias or directly.
        def references?(identifier)
          if identifier.is_a?(Alias)
            return true if prefix?(identifier.altname)
            identifier = identifier.reference
          end

          prefix?(identifier.last)
        end

        def to_mql(context = {})
          if context[:expr]
            # emit the identifier as appropriate for appearing within $expr operation

            # 1. if it isn't qualified, that's an error
            raise NotImplementedError, 'identifiers must be qualified' if !qualified?

            if context[:let]
              # 2. if context[:current] && qualified with current collection:
              #            - no let assignment needed
              #            - variable name = "$field" (remove qualification)
              if context[:current] && references?(context[:current])
                "$#{mql_name(last)}"

              # 3. if qualified with the primary collection:
              #            - add variable to :let ("primary_field" => "$field")
              #            - variable name = "$$primary_field"
              elsif context[:primary] && references?(context[:primary])
                context[:let][joined '_'] = "$#{mql_name(last)}"
                "$$#{joined "_"}"

              # 4. if qualified with a different collection (we'll assume the other
              #    collection has already been joined previously):
              #            - add variable to :let ("other_field" => "$other.field")
              #            - variable name = "$$other_field"
              else
                # we know it's qualified because if it isn't qualified, that's an
                # error (see #1 above)
                context[:let][joined '_'] = "$#{joined}"
                "$$#{joined "_"}"
              end
            elsif context[:primary] && references?(context[:primary])
              "$#{mql_name(last)}"
            else
              "$#{joined}"
            end
          else
            joined
          end
        end

        private

        def mql_name(ident)
          ident == 'id' ? '_id' : ident
        end
      end
    end
  end
end
