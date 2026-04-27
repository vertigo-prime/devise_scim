# frozen_string_literal: true

require "json"

module DeviseScim
  module Scim
    USER_SCHEMA       = "urn:ietf:params:scim:schemas:core:2.0:User"
    ENTERPRISE_SCHEMA = "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"

    Name        = Struct.new(:formatted, :given_name, :family_name, :middle_name,
                             :honorific_prefix, :honorific_suffix, keyword_init: true)
    Email       = Struct.new(:value, :type, :primary, keyword_init: true)
    PhoneNumber = Struct.new(:value, :type, :primary, keyword_init: true)
    Meta        = Struct.new(:resource_type, :created, :last_modified, :version, :location,
                             keyword_init: true)

    # rubocop:disable Metrics/ClassLength
    class User
      SCHEMAS = [USER_SCHEMA].freeze

      attr_accessor :id, :external_id, :user_name, :display_name, :nick_name,
                    :profile_url, :title, :user_type, :preferred_language,
                    :locale, :timezone, :active, :name, :emails, :phone_numbers,
                    :groups, :meta

      class << self
        def from_h(hash)
          user = new
          assign_scalars(user, hash)
          assign_name(user, hash)
          user.emails        = parse_emails(hash)
          user.phone_numbers = parse_phones(hash)
          user
        end

        private

        # rubocop:disable Metrics/AbcSize
        def assign_scalars(user, hash)
          user.id                 = hash["id"]
          user.external_id        = hash["externalId"]
          user.user_name          = hash["userName"]
          user.display_name       = hash["displayName"]
          user.nick_name          = hash["nickName"]
          user.profile_url        = hash["profileUrl"]
          user.title              = hash["title"]
          user.user_type          = hash["userType"]
          user.preferred_language = hash["preferredLanguage"]
          user.locale             = hash["locale"]
          user.timezone           = hash["timezone"]
          user.active             = hash.key?("active") ? hash["active"] : true
        end
        # rubocop:enable Metrics/AbcSize

        def assign_name(user, hash)
          return unless (n = hash["name"])

          user.name = Name.new(
            formatted: n["formatted"],
            given_name: n["givenName"],
            family_name: n["familyName"],
            middle_name: n["middleName"],
            honorific_prefix: n["honorificPrefix"],
            honorific_suffix: n["honorificSuffix"]
          )
        end

        def parse_emails(hash)
          Array(hash["emails"]).map do |entry|
            Email.new(value: entry["value"], type: entry["type"], primary: entry["primary"])
          end
        end

        def parse_phones(hash)
          Array(hash["phoneNumbers"]).map do |entry|
            PhoneNumber.new(value: entry["value"], type: entry["type"], primary: entry["primary"])
          end
        end
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def to_h
        h = base_hash.compact
        h["schemas"] = SCHEMAS
        h["name"]         = serialize_name           if name
        h["emails"]       = serialize_emails         if emails&.any?
        h["phoneNumbers"] = serialize_phones         if phone_numbers&.any?
        h["groups"]       = groups                   if groups&.any?
        h["meta"]         = serialize_meta(meta, "User") if meta
        h
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def to_json(*)
        to_h.to_json
      end

      def primary_email
        emails&.find(&:primary)&.value || user_name
      end

      private

      def base_hash
        {
          "schemas" => SCHEMAS,
          "id" => id,
          "externalId" => external_id,
          "userName" => user_name,
          "displayName" => display_name,
          "nickName" => nick_name,
          "profileUrl" => profile_url,
          "title" => title,
          "userType" => user_type,
          "preferredLanguage" => preferred_language,
          "locale" => locale,
          "timezone" => timezone,
          "active" => active
        }
      end

      def serialize_name
        {
          "formatted" => name.formatted,
          "givenName" => name.given_name,
          "familyName" => name.family_name,
          "middleName" => name.middle_name,
          "honorificPrefix" => name.honorific_prefix,
          "honorificSuffix" => name.honorific_suffix
        }.compact
      end

      def serialize_emails
        emails.map do |email|
          { "value" => email.value, "type" => email.type, "primary" => email.primary }.compact
        end
      end

      def serialize_phones
        phone_numbers.map do |phone|
          { "value" => phone.value, "type" => phone.type, "primary" => phone.primary }.compact
        end
      end

      def serialize_meta(met, resource_type)
        {
          "resourceType" => met.resource_type || resource_type,
          "created" => iso8601_or_raw(met.created),
          "lastModified" => iso8601_or_raw(met.last_modified),
          "version" => met.version,
          "location" => met.location
        }.compact
      end

      def iso8601_or_raw(value)
        value.respond_to?(:iso8601) ? value.iso8601 : value
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
