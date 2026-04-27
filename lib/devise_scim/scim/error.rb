# frozen_string_literal: true

require "json"

module DeviseScim
  module Scim
    ERROR_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:Error"

    class Error
      attr_reader :status, :detail, :scim_type

      def initialize(status:, detail:, scim_type: nil)
        @status    = status
        @detail    = detail
        @scim_type = scim_type
      end

      def to_h
        h = {
          "schemas" => [ERROR_SCHEMA],
          "status" => status.to_s,
          "detail" => detail
        }
        h["scimType"] = scim_type if scim_type
        h
      end

      def to_json(*)
        to_h.to_json
      end

      class << self
        def unauthorized(detail = "Unauthorized")
          new(status: 401, detail: detail)
        end

        def not_found(detail = "Resource not found")
          new(status: 404, detail: detail)
        end

        def conflict(detail = "Resource already exists", scim_type: "uniqueness")
          new(status: 409, detail: detail, scim_type: scim_type)
        end

        def bad_request(detail, scim_type: "invalidValue")
          new(status: 400, detail: detail, scim_type: scim_type)
        end

        def unprocessable(detail)
          new(status: 422, detail: detail)
        end

        def server_error(detail = "Internal server error")
          new(status: 500, detail: detail)
        end
      end
    end
  end
end
