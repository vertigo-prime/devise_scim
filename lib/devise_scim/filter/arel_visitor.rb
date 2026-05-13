# frozen_string_literal: true

module DeviseScim
  module Filter
    # Translates a Filter AST into Arel conditions applied to an AR scope.
    class ArelVisitor
      SCIM_TO_AR = {
        "userName" => "email",
        "externalId" => "scim_uid",
        "active" => "scim_active",
        "id" => "id",
        "emails" => "email",
        "emails.value" => "email",
        "name.givenName" => "first_name",
        "name.familyName" => "last_name"
      }.freeze

      def initialize(model)
        @model = model
        @table = model.arel_table
      end

      def apply(ast, scope)
        scope.where(visit(ast))
      end

      private

      def visit(node)
        case node
        when Comparison  then visit_comparison(node)
        when Conjunction then visit(node.left).and(visit(node.right))
        when Disjunction then visit(node.left).or(visit(node.right))
        when AttrPath    then visit_attr_path(node)
        else raise InvalidFilter, "Unknown AST node: #{node.class}"
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      def visit_comparison(node)
        col_name = SCIM_TO_AR[node.attr_path] || node.attr_path
        col = resolve_column(col_name)
        val = node.value

        case node.op
        when "eq" then col.eq(val)
        when "ne" then col.not_eq(val)
        when "co" then col.matches("%#{sanitize_like(val)}%")
        when "sw" then col.matches("#{sanitize_like(val)}%")
        when "ew" then col.matches("%#{sanitize_like(val)}")
        when "pr" then col.not_eq(nil)
        when "gt" then col.gt(val)
        when "ge" then col.gteq(val)
        when "lt" then col.lt(val)
        when "le" then col.lteq(val)
        else raise InvalidFilter, "Unknown operator '#{node.op}'"
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def visit_attr_path(node)
        col_name = SCIM_TO_AR[node.attribute] || node.attribute
        resolve_column(col_name).not_eq(nil)
      end

      def resolve_column(col_name)
        raise InvalidFilter, "Unknown attribute '#{col_name}'" unless @model.column_names.include?(col_name)

        @table[col_name]
      end

      def sanitize_like(str)
        str.gsub(/[%_\\]/) { |c| "\\#{c}" }
      end
    end
  end
end
