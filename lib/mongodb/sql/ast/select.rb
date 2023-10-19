# frozen_string_literal: true

module MongoDB
  module SQL
    module AST
      class Select
        include Dumpable
        dumpable :select_list, :table_expr, :distinct

        def initialize(select_list, table_expr, distinct)
          @select_list, @table_expr = select_list, table_expr
          @distinct = distinct
        end

        def to_mql(context = {})
          command = table_expr.to_mql(context)
          context = context.merge(primary: command.target)

          if distinct || count_node&.distinct
            group = build_distinct(context)
            command = command.append(*group)
          end

          group = build_count(context)
          command = command.append(*group) if group

          projection = build_projection(context)
          command = command.append(*projection) if projection

          command
        end

        private

        # returns the SQL::AST::Count node from the select list, if there
        # is one. If there is more than one, raises an exception.
        def count_node
          @count_node ||= begin
            counts = select_list.select { |i| i.is_a?(SQL::AST::Count) }
            raise 'multiple counts in a single is not supported' if counts.length > 1

            count = counts.first || :none
          end

          @count_node == :none ? nil : @count_node
        end

        def build_distinct(context)
          field_name = ->(ident) {
            ident.unqualified == 'id' ? '_id' : ident.unqualified
          }

          fields = if count_node&.distinct
                    [ count_node.ident ]
                  else
                    select_list
                  end

          id = if fields.length == 1
                "$#{field_name[fields.first]}"
              else
                fields.each_with_object({}) { |field, doc| doc[field_name[field]] = "$#{field_name[field]}" }
              end

          group = { '$group' => { '_id' => id } }

          # the trivial case, when grouping by the existing _id; we don't
          # need to re-project anything.
          return [ group, { '$project' => { 'id' => '$_id' }} ] if id == '$_id'

          # now, build a project stage that deconstructs the _id and puts
          # the corresponding fields back into the document.
          projection = { '_id' => 0 }.tap do |doc|
            if id.is_a?(Hash)
              id.keys.each do |key|
                doc[key] = "$_id.#{key}"
              end
            else
              doc[id.tr('$','')] = '$_id'
            end
          end

          project = { '$project' => projection }

          [ group, project ]
        end

        def build_count(context)
          return unless count_node

          [{
            '$group' => {
              '_id' => nil,
              count_node.full => { '$sum' => 1 }
            }
          }]
        end

        def build_projection(context)
          return unless select_list.none? { |i| i.asterisk? }

          set = select_list.each_with_object({}) do |item, map|
            is_aliased = item.aliased?

            if item.constant?
              project_as = is_aliased ? item.altname : item.constant.to_s
              field = { '$literal' => item.constant }
            else
              project_as = is_aliased ? item.altname : item.unqualified
              field = item.unqualified

              if !context[:primary] || !item.references?(context[:primary])
                # if it is qualified and doesn't reference the primary, then it was
                # joined in and we need to flatten the projected document fields
                if !item.aliased? && item.deref.qualified?
                  project_as = item.deref.joined '_'
                  is_aliased = true
                end

                field = item.full
              end

              field = '_id' if field == 'id'
              field = "$#{field}"
            end

            map[project_as] = is_aliased ? field : 1
          end

          # need to make sure we don't unset the _id if we're explicitly
          # projecting it previously.
          set['_id'] ||= 0

          [{ '$project' => set }]
        end
      end
    end
  end
end
