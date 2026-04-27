# frozen_string_literal: true

module DeviseScim
  module RSpec
    module ScimHelpers
      def scim_json(body)
        JSON.parse(body)
      end

      def scim_prefix
        DeviseScim.configuration.route_prefix
      end

      def scim_auth_headers(token)
        { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
      end

      def scim_user_payload(user_name:, **attrs)
        base = { "schemas" => [DeviseScim::Scim::USER_SCHEMA], "userName" => user_name }
        base.merge(attrs.transform_keys(&:to_s))
      end

      def scim_patch_payload(*operations)
        {
          "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
          "Operations" => operations
        }
      end

      def scim_replace_op(path, value)
        { "op" => "replace", "path" => path, "value" => value }
      end

      def scim_add_op(path, value)
        { "op" => "add", "path" => path, "value" => value }
      end

      def scim_remove_op(path)
        { "op" => "remove", "path" => path }
      end
    end
  end
end
