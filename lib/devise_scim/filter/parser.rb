# frozen_string_literal: true

module DeviseScim
  module Filter
    Comparison = Struct.new(:attr_path, :op, :value, keyword_init: true)
    Conjunction = Struct.new(:left, :right, keyword_init: true)
    Disjunction = Struct.new(:left, :right, keyword_init: true)
    AttrPath    = Struct.new(:attribute, :sub_filter, :sub_attr, keyword_init: true)

    # Recursive descent parser for SCIM filter expressions (RFC 7644 §3.4.2.2).
    # Supported: eq/ne/co/sw/ew/pr/gt/ge/lt/le, and/or, attr[sub-filter].sub-attr comparisons.
    class Parser # rubocop:disable Metrics/ClassLength
      class ParseError < ::DeviseScim::InvalidFilter; end

      Token = Struct.new(:type, :value, keyword_init: true)

      COMP_OPS = %w[eq ne co sw ew pr gt ge lt le].freeze

      def self.parse(str)
        new(str).parse
      end

      def initialize(str)
        @tokens = tokenize(str)
        @pos    = 0
      end

      def parse
        ast = parse_or
        raise ParseError, "Unexpected token '#{current&.value}'" unless at_end?

        ast
      end

      private

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
      def tokenize(str)
        tokens = []
        s = str.strip
        until s.empty?
          s = s.lstrip
          break if s.empty?

          # Use explicit match objects so String#gsub doesn't clobber $&.
          if (m = /\A"((?:[^"\\]|\\.)*)"/.match(s))
            tokens << Token.new(type: :string, value: m[1].gsub('\\"', '"'))
            s = s[m[0].length..]
          elsif (m = /\Atrue\b/i.match(s))
            tokens << Token.new(type: :boolean, value: true)
            s = s[m[0].length..]
          elsif (m = /\Afalse\b/i.match(s))
            tokens << Token.new(type: :boolean, value: false)
            s = s[m[0].length..]
          elsif (m = /\Anull\b/i.match(s))
            tokens << Token.new(type: :null, value: nil)
            s = s[m[0].length..]
          elsif (m = /\Anot\b/i.match(s))
            tokens << Token.new(type: :not, value: "not")
            s = s[m[0].length..]
          elsif (m = /\Aand\b/i.match(s))
            tokens << Token.new(type: :and, value: "and")
            s = s[m[0].length..]
          elsif (m = /\Aor\b/i.match(s))
            tokens << Token.new(type: :or, value: "or")
            s = s[m[0].length..]
          elsif (m = /\A(eq|ne|co|sw|ew|pr|gt|ge|lt|le)\b/i.match(s))
            tokens << Token.new(type: :op, value: m[1].downcase)
            s = s[m[0].length..]
          elsif s.start_with?("(")
            tokens << Token.new(type: :lparen, value: "(")
            s = s[1..]
          elsif s.start_with?(")")
            tokens << Token.new(type: :rparen, value: ")")
            s = s[1..]
          elsif s.start_with?("[")
            tokens << Token.new(type: :lbracket, value: "[")
            s = s[1..]
          elsif s.start_with?("]")
            tokens << Token.new(type: :rbracket, value: "]")
            s = s[1..]
          elsif s.start_with?(".")
            tokens << Token.new(type: :dot, value: ".")
            s = s[1..]
          elsif (m = /\A[\w:-]+/.match(s))
            tokens << Token.new(type: :identifier, value: m[0])
            s = s[m[0].length..]
          elsif (m = /\A-?\d+(\.\d+)?/.match(s))
            tokens << Token.new(type: :number, value: m[0].to_f)
            s = s[m[0].length..]
          else
            raise ParseError, "Unexpected character '#{s[0]}'"
          end
        end
        tokens
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

      def parse_or
        left = parse_and
        while current&.type == :or
          advance
          left = Disjunction.new(left: left, right: parse_and)
        end
        left
      end

      def parse_and
        left = parse_primary
        while current&.type == :and
          advance
          left = Conjunction.new(left: left, right: parse_primary)
        end
        left
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def parse_primary
        if current&.type == :lparen
          advance
          node = parse_or
          expect!(:rparen)
          return node
        end

        attr = expect!(:identifier).value

        if current&.type == :lbracket
          advance
          sub_filter = parse_or
          expect!(:rbracket)
          sub_attr = extract_sub_attr
          if current&.type == :op
            op  = advance.value
            val = parse_value
            Comparison.new(attr_path: sub_attr ? "#{attr}.#{sub_attr}" : attr, op: op, value: val)
          else
            AttrPath.new(attribute: attr, sub_filter: sub_filter, sub_attr: sub_attr)
          end
        elsif current&.type == :op
          op  = advance.value
          val = op == "pr" ? nil : parse_value
          Comparison.new(attr_path: attr, op: op, value: val)
        else
          raise ParseError, "Expected comparator after '#{attr}', got #{current&.value.inspect}"
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def extract_sub_attr
        return nil unless current&.type == :dot

        advance
        expect!(:identifier).value
      end

      def parse_value
        tok = current
        case tok&.type
        when :string, :boolean, :null, :number
          advance
          tok.value
        else
          raise ParseError, "Expected value, got #{tok&.value.inspect}"
        end
      end

      def current
        @tokens[@pos]
      end

      def advance
        tok = @tokens[@pos]
        @pos += 1
        tok
      end

      def at_end?
        @pos >= @tokens.length
      end

      def expect!(type)
        tok = advance
        raise ParseError, "Expected #{type}, got #{tok&.type} (#{tok&.value.inspect})" unless tok&.type == type

        tok
      end
    end
  end
end
