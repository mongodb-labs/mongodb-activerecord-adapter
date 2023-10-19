# frozen_string_literal: true

require 'strscan'

module MongoDB
  module SQL
    class Tokenizer
      OPERATOR = /<=|>=|<|>|=|-|\+/
      PUNCTUATION = /[*,\()\.;]/
      KEYWORD = /\b(select|from|where|group|by|having|order|distinct|offset|left|right|outer|inner|join|on|as|natural|avg|sum|count|and|or|not|insert|into|default|values|update|set|delete|between|like|in|null|true|false|case|when|then|else|end|asc|desc|limit|is|create|table|primary|index|unique|savepoint)\b/i
      FLOAT = /\d+\.\d+/
      INTEGER = /\d+/
      IDENT = /\w+/
      EOL_COMMENT = /--.*$/
      MULTI_COMMENT = /\/\*.*\*\//m

      def initialize(string)
        @scanner = StringScanner.new(string)
        @token_stack = []
      end

      def next
        return @token_stack.pop if @token_stack.any?

        skip_white!
        return nil if @scanner.eos?

        if @scanner.scan(OPERATOR) || @scanner.scan(PUNCTUATION)
          { token: @scanner.matched, value: @scanner.matched }
        elsif @scanner.scan(/['"]/)
          { token: matched_string_type, value: scan_string(@scanner.matched) }
        elsif @scanner.scan('?')
          { token: :variable, value: @scanner.matched }
        elsif @scanner.scan(FLOAT)
          { token: :number, value: @scanner.matched.to_f }
        elsif @scanner.scan(INTEGER)
          { token: :number, value: @scanner.matched.to_i }
        elsif @scanner.scan(KEYWORD)
          { token: @scanner.matched.downcase.to_sym }
        elsif @scanner.scan(IDENT)
          { token: :ident, value: @scanner.matched }
        else
          raise "invalid input: #{@scanner.peek(1)}"
        end
      end

      def peek
        self.next.tap { |token| push(token) if token }
      end

      def next_is?(token_type, mode = :consume)
        token = self.next
        return false unless token

        if match_token_type?(token_type, token)
          case mode
          when :consume then # nothing, already consumed
          when :peek then push token
          else raise ArgumentError, "unknown mode #{mode.inspect}"
          end

          token
        else
          push token
          false
        end
      end

      def push(token)
        @token_stack.push token
      end

      def expect!(token_type, value = nil)
        self.next.tap do |token|
          if !match_token_type?(token_type, token)
            raise "expected #{token_type.inspect}, got #{token.inspect}"
          end
          if value && !token[:value] == value
            raise "expected #{token_type.inspect} to have value #{value.inspect }, got #{token[:value].inspect}"
          end
        end
      end

      def eof?
        peek.nil?
      end

      def skip_white!
        while @scanner.skip(/\s+/) ||
          @scanner.skip(EOL_COMMENT) ||
          @scanner.skip(MULTI_COMMENT)
        end
      end

    private

      def matched_string_type
        case @scanner.matched
        when '"' then :dquote
        when "'" then :squote
        else raise ArgumentError, "unsupported string delimiter #{@scanner.matched.inspect}"
        end
      end

      def scan_string(delim)
        # TODO: fit the spec, here. The following is a super-naïve version
        @scanner.scan(/[^#{delim}]*/).tap do
          @scanner.scan(delim) or raise 'unterminated string'
        end
      end

      def match_token_type?(pattern, token)
        return false if token.nil?

        case pattern
        when Array then pattern.any? { match_token_type?(_1, token) }
        when Hash then pattern.keys.all? { |key| token[key] == pattern[key] }
        else token[:token] == pattern
        end
      end
    end
  end
end
