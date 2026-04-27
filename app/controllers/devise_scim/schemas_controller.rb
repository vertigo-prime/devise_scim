# frozen_string_literal: true

module DeviseScim
  class SchemasController < ApplicationController
    LIST_SCHEMA = "urn:ietf:params:scim:api:messages:2.0:ListResponse"
    SCHEMA_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:Schema"

    def index
      schemas = [user_schema]
      schemas << group_schema if DeviseScim.configuration.enable_groups
      payload = {
        "schemas" => [LIST_SCHEMA],
        "totalResults" => schemas.size,
        "Resources" => schemas
      }
      render_scim(payload)
    end

    private

    def user_schema
      {
        "schemas" => [SCHEMA_SCHEMA],
        "id" => Scim::USER_SCHEMA,
        "name" => "User",
        "description" => "User Account",
        "attributes" => user_attributes
      }
    end

    def group_schema
      {
        "schemas" => [SCHEMA_SCHEMA],
        "id" => Scim::GROUP_SCHEMA,
        "name" => "Group",
        "description" => "Group",
        "attributes" => [
          { "name" => "displayName", "type" => "string", "multiValued" => false, "required" => true },
          { "name" => "members",     "type" => "complex", "multiValued" => true, "required" => false }
        ]
      }
    end

    def user_attributes
      [
        { "name" => "userName",    "type" => "string",  "multiValued" => false, "required" => true },
        { "name" => "name",        "type" => "complex", "multiValued" => false, "required" => false },
        { "name" => "emails",      "type" => "complex", "multiValued" => true,  "required" => false },
        { "name" => "phoneNumbers", "type" => "complex", "multiValued" => true, "required" => false },
        { "name" => "active",      "type" => "boolean", "multiValued" => false, "required" => false },
        { "name" => "externalId",  "type" => "string",  "multiValued" => false, "required" => false }
      ]
    end
  end
end
