# frozen_string_literal: true

require 'mongodb/sql/tokenizer'
require 'mongodb/sql/ast'

module MongoDB
  module SQL
    class Parser
      IDENTABLE = %i( ident dquote )

      def initialize
        @next_position = 0
      end

      def parse_statement(tokens)
        token = tokens.peek
        case token[:token]
        when :select then parse_select(tokens)
        when :insert then parse_insert(tokens)
        when :update then parse_update(tokens)
        when :delete then parse_delete(tokens)
        when :create then parse_create(tokens)
        when :savepoint then
          raise NotImplementedError, 'savepoints are not supported'
        else raise "not sure how to parse #{token.inspect}"
        end.tap do
          tokens.next_is? ';' # skip any trailing semicolon

          if !tokens.eof?
            raise "parse finished with tokens remaining in the stream: #{tokens.peek.inspect}"
          end
        end
      end

      def parse_select(tokens)
        tokens.expect! :select
        distinct = tokens.next_is? :distinct
        SQL::AST::Select.new(
          parse_select_list(tokens),
          parse_table_expr(tokens),
          distinct)
      end

      def parse_insert(tokens)
        tokens.expect! :insert
        tokens.expect! :into

        target = parse_simple_identifier(tokens)

        if tokens.next_is? :default
          tokens.expect! :values
        else
          tokens.expect! '('
          columns = parse_delimited_list(tokens, ',') { parse_simple_identifier(tokens) }
          tokens.expect! ')'
          tokens.expect! :values
          tokens.expect! '('
          values = parse_delimited_list(tokens, ',') { parse_simple_value(tokens) }
          tokens.expect! ')'
        end

        SQL::AST::Insert.new(target, columns, values)
      end

      def parse_update(tokens)
        tokens.expect! :update

        target = parse_simple_identifier(tokens)
        set_list = parse_set_clause_list(tokens)

        if tokens.next_is? :where
          condition = parse_search_condition(tokens)
        end

        SQL::AST::Update.new(target, set_list, condition)
      end

      def parse_delete(tokens)
        tokens.expect! :delete
        tokens.expect! :from

        target = parse_simple_identifier(tokens)

        if tokens.next_is? :where
          condition = parse_search_condition(tokens)
        end

        SQL::AST::Delete.new(target, condition)
      end

      def parse_create(tokens)
        tokens.expect! :create

        if tokens.next_is? :unique
          tokens.expect! :index
          parse_create_index(tokens, true)
        elsif tokens.next_is? :index
          parse_create_index(tokens, false)
        elsif tokens.next_is? :table
          parse_create_table(tokens)
        else
          raise "expected INDEX, UNIQUE, or TABLE, got #{tokens.peek.inspect}"
        end
      end

      def parse_create_index(tokens, unique)
        name = parse_simple_identifier(tokens)
        tokens.expect! :on
        table_name = parse_simple_identifier(tokens)
        tokens.expect! '('

        columns = []
        loop do
          columns.push parse_simple_identifier(tokens)
          break unless tokens.next_is? ','
        end
        tokens.expect! ')'

        SQL::AST::Index.new(name, table_name, columns, unique: unique)
      end

      def parse_create_table(tokens)
        name = parse_simple_identifier(tokens)

        tokens.expect! '('
        columns = parse_column_definitions(tokens)
        tokens.expect! ')'

        SQL::AST::Table.new(name, columns)
      end

      def parse_column_definitions(tokens)
        [].tap do |columns|
          loop do
            columns.push(parse_column_definition(tokens))
            break unless tokens.next_is? ','
          end
        end
      end

      def parse_column_definition(tokens)
        name = parse_simple_identifier(tokens)
        type = parse_simple_identifier(tokens)
        constraints = parse_column_constraints(tokens)
        SQL::AST::Column.new(name, type, constraints)
      end

      def parse_column_constraints(tokens)
        [].tap do |list|
          loop do
            constraint = parse_column_constraint(tokens)
            break unless constraint

            list.push constraint
          end
        end
      end

      def parse_column_constraint(tokens)
        if tokens.next_is? :not
          tokens.expect! :null
          return :not_null
        elsif tokens.next_is? :primary
          tokens.expect! :ident, 'key'
          return :primary_key
        end
      end

      def parse_select_list(tokens)
        parse_delimited_list(tokens, ',') { |toks|
          parse_select_sublist(toks) }
      end

      def parse_set_clause_list(tokens)
        tokens.expect! :set
        parse_delimited_list(tokens, ',') do
          column = parse_simple_identifier(tokens)
          tokens.expect! '='
          value = parse_simple_value(tokens) || parse_simple_identifier(tokens)
          { column: column, value: value }
        end
      end

      def parse_table_expr(tokens)
        SQL::AST::TableExpr.new(
          parse_from_clause(tokens),
          parse_optional_where_clause(tokens),
          parse_optional_order_clause(tokens),
          parse_optional_limit_clause(tokens)
        )
      end

      def parse_from_clause(tokens)
        tokens.expect! :from
        list = parse_delimited_list(tokens, ',') { |toks| parse_table_reference(toks) }
        SQL::AST::FromClause.new(list)
      end

      def parse_optional_where_clause(tokens)
        return unless tokens.next_is? :where
        SQL::AST::WhereClause.new(parse_search_condition(tokens))
      end

      def parse_optional_order_clause(tokens)
        return unless tokens.next_is? :order
        tokens.expect! :by
        SQL::AST::OrderClause.new(parse_sort_specification_list(tokens))
      end

      def parse_optional_limit_clause(tokens)
        return unless tokens.next_is? :limit
        SQL::AST::LimitClause.new(parse_simple_value(tokens))
      end

      # <aliasable> [ <join-type> <aliasable> ON <condition> ]*
      def parse_table_reference(tokens)
        reference = parse_aliasable(tokens)
        joins = parse_joins(tokens)

        SQL::AST::TableRef.new(reference, joins)
      end

      def parse_joins(tokens)
        [].tap do |joins|
          loop do
            join_type = parse_join_type(tokens) or break
            reference = parse_aliasable(tokens)
            tokens.expect! :on
            condition = parse_search_condition(tokens)

            joins.push SQL::AST::Join.new(join_type, reference, condition)
          end
        end
      end

      def parse_join_type(tokens)
        type = if tokens.next_is?(:left)
          tokens.next_is?(:outer) # optional 'outer'
          :left
        elsif tokens.next_is?(:inner)
          :inner
        else
          nil
        end

        if type || tokens.next_is?(:join, :peek)
          tokens.expect! :join
          type ||= :inner
        end

        type
      end

      def parse_select_sublist(tokens)
        parse_aliasable(tokens, allow_star: true)
      end

      def parse_search_condition(tokens)
        left = parse_boolean_and(tokens)
        if tokens.next_is?(:or)
          right = parse_search_condition(tokens)
          SQL::AST::BinaryExpression.new(left, :or, right)
        else
          left
        end
      end

      def parse_boolean_and(tokens)
        left = parse_boolean_comparison(tokens)
        if tokens.next_is?(:and)
          right = parse_boolean_and(tokens)
          SQL::AST::BinaryExpression.new(left, :and, right)
        else
          left
        end
      end

      def parse_boolean_comparison(tokens)
        left = parse_boolean_factor(tokens)
        token = tokens.next_is?([ '<=', '<', '=', '>', '>=', :is ])
        if token
          right = parse_boolean_factor(tokens)
          SQL::AST::BinaryExpression.new(left, token[:token], right)
        else
          left
        end
      end

      def parse_boolean_factor(tokens)
        if tokens.next_is? :not
          SQL::AST::UnaryExpression.new(:not, parse_boolean_factor(tokens))
        elsif tokens.next_is? '('
          parse_search_condition(tokens).tap { tokens.expect! ')' }
        elsif tokens.next_is?(IDENTABLE, :peek)
          parse_identifier(tokens)
        elsif (result = parse_simple_value(tokens))
          result
        else
          raise "unexpected token: #{tokens.peek.inspect}"
        end
      end

      def parse_simple_value(tokens)
        if (token = tokens.next_is?(%i(number squote null)))
          SQL::AST::Constant.new(token[:value])
        elsif (token = tokens.next_is?(:variable))
          SQL::AST::Variable.new(token[:value], next_position)
        end
      end

      def parse_identifier(tokens, allow_star: false)
        # identifier := simple_identifier ( '.' simple_identifier )*
        # simple_identifier := ident | '"' string '"'
        parts = []
        loop do
          if allow_star && (token = tokens.next_is?('*'))
            parts.push token
            break
          else
            parts.push parse_simple_identifier(tokens)
          end

          break unless tokens.next_is?('.')
        end

        SQL::AST::Identifier.new(parts)
      end

      def parse_simple_identifier(tokens)
        tokens.expect! IDENTABLE
      end

      def parse_aliasable(tokens, allow_star: false)
        token = tokens.peek
        is_asterisk = false

        value = case token[:token]
          when :number, :squote then tokens.next
          when :count then parse_count(tokens, allow_star: allow_star)
          else
            parse_identifier(tokens, allow_star: allow_star).tap do |identifier|
              is_asterisk = identifier.asterisk?
            end
          end

        needs_alias = !is_asterisk && tokens.next_is?(:as)
        if needs_alias || tokens.next_is?(IDENTABLE, :peek)
          id_alias = parse_simple_identifier(tokens)
          SQL::AST::Alias.new(value, id_alias)
        else
          value
        end
      end

      def parse_count(tokens, allow_star: false)
        tokens.expect! :count
        tokens.expect! '('
        distinct = tokens.next_is? :distinct
        ident = parse_identifier(tokens, allow_star: allow_star)
        tokens.expect! ')'

        SQL::AST::Count.new(ident, distinct)
      end

      def parse_sort_specification_list(tokens)
        parse_delimited_list(tokens, ',') do |toks|
          key = parse_identifier(toks)
          order = tokens.next_is?(%i( asc desc ))
          { key: key, order: order }
        end
      end

      def parse_delimited_list(tokens, delim)
        list = []

        loop do
          list.push yield(tokens)
          break unless tokens.next_is? delim
        end

        list
      end

      def next_position
        @next_position.tap { @next_position +=1 }
      end
    end
  end
end
