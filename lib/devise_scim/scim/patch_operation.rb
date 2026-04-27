# frozen_string_literal: true

module DeviseScim
  module Scim
    PATCH_OP_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:PatchOp"

    class PatchOperation
      VALID_OPS = %w[add remove replace].freeze

      attr_reader :op, :raw_path, :value, :attribute, :filter, :sub_attribute

      def self.parse(hash)
        operation = hash["op"]&.downcase
        raise ArgumentError, "Invalid op '#{hash["op"]}'; must be one of: #{VALID_OPS.join(", ")}" unless VALID_OPS.include?(operation)

        new(operation: operation, path: hash["path"], value: hash["value"])
      end

      def self.parse_request(body)
        ops = body["Operations"] || body["operations"] || []
        ops.map { |op_hash| parse(op_hash) }
      end

      def initialize(operation:, path:, value: nil)
        @op = operation
        @raw_path = path
        @value = value
        parse_path(path)
      end

      private

      # Handles three path forms:
      #   "active"                            → attribute: "active"
      #   "name.givenName"                    → attribute: "name", sub_attribute: "givenName"
      #   "emails[type eq \"work\"].value"    → attribute: "emails", filter: "...", sub_attribute: "value"
      #   "emails[type eq \"work\"]"          → attribute: "emails", filter: "..."
      def parse_path(path)
        return unless path

        if (match = path.match(/\A(\w+)\[(.+?)\](?:\.(\w+))?\z/))
          @attribute     = match[1]
          @filter        = match[2]
          @sub_attribute = match[3]
        elsif path.include?(".")
          parts          = path.split(".", 2)
          @attribute     = parts[0]
          @sub_attribute = parts[1]
        else
          @attribute = path
        end
      end
    end
  end
end
