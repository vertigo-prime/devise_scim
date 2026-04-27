# frozen_string_literal: true

module DeviseScim
  module Minitest
    module ScimAssertions
      def assert_scim_status(response, expected_status)
        assert_equal expected_status.to_s, response.status.to_s,
                     "Expected SCIM status #{expected_status}, got #{response.status}\n#{response.body}"
      end

      def assert_scim_content_type(response)
        assert_includes response.content_type, "application/scim+json",
                        "Expected Content-Type application/scim+json"
      end

      def assert_scim_schema(response, expected_schema)
        body = JSON.parse(response.body)
        assert_includes body["schemas"], expected_schema,
                        "Expected schema #{expected_schema.inspect} in #{body["schemas"].inspect}"
      end

      def assert_scim_list_response(response)
        body = JSON.parse(response.body)
        assert_scim_schema(response, DeviseScim::Scim::LIST_RESPONSE_SCHEMA)
        assert body.key?("totalResults"), "Expected totalResults key in ListResponse"
        assert body.key?("Resources"),    "Expected Resources key in ListResponse"
      end

      def assert_scim_error(response, expected_status: nil)
        body = JSON.parse(response.body)
        assert_includes body["schemas"], DeviseScim::Scim::ERROR_SCHEMA,
                        "Expected SCIM error schema in response"
        assert_equal expected_status.to_s, body["status"] if expected_status
      end

      def scim_json(response)
        JSON.parse(response.body)
      end

      def scim_auth_headers(token)
        { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
      end

      def scim_user_payload(user_name:, **attrs)
        { "schemas" => [DeviseScim::Scim::USER_SCHEMA], "userName" => user_name }
          .merge(attrs.transform_keys(&:to_s))
      end

      def scim_patch_payload(*operations)
        {
          "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
          "Operations" => operations
        }
      end
    end
  end
end
