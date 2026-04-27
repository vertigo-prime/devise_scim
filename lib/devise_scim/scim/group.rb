# frozen_string_literal: true

require "json"

module DeviseScim
  module Scim
    GROUP_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:Group"

    # rubocop:disable Lint/StructNewOverride
    Member = Struct.new(:value, :display, :ref, keyword_init: true)
    # rubocop:enable Lint/StructNewOverride

    class Group
      SCHEMAS = [GROUP_SCHEMA].freeze

      attr_accessor :id, :external_id, :display_name, :members, :meta

      def self.from_h(hash)
        group = new
        group.id           = hash["id"]
        group.external_id  = hash["externalId"]
        group.display_name = hash["displayName"]
        group.members = Array(hash["members"]).map do |entry|
          Member.new(value: entry["value"], display: entry["display"], ref: entry["$ref"])
        end
        group
      end

      def to_h
        h = {
          "schemas" => SCHEMAS,
          "id" => id,
          "externalId" => external_id,
          "displayName" => display_name,
          "members" => (members || []).map { |member| serialize_member(member) }
        }.compact
        h["schemas"]  = SCHEMAS
        h["members"]  = (members || []).map { |member| serialize_member(member) }
        h["meta"]     = serialize_meta if meta
        h
      end

      def to_json(*)
        to_h.to_json
      end

      private

      def serialize_member(member)
        { "value" => member.value, "display" => member.display, "$ref" => member.ref }.compact
      end

      def serialize_meta
        {
          "resourceType" => meta.resource_type || "Group",
          "created" => iso8601_or_raw(meta.created),
          "lastModified" => iso8601_or_raw(meta.last_modified)
        }.compact
      end

      def iso8601_or_raw(value)
        value.respond_to?(:iso8601) ? value.iso8601 : value
      end
    end
  end
end
