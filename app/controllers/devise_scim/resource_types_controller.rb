# frozen_string_literal: true

module DeviseScim
  class ResourceTypesController < ApplicationController
    LIST_SCHEMA          = "urn:ietf:params:scim:api:messages:2.0:ListResponse"
    RESOURCE_TYPE_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:ResourceType"

    def index
      types = [user_resource_type]
      types << group_resource_type if DeviseScim.configuration.enable_groups
      payload = {
        "schemas" => [LIST_SCHEMA],
        "totalResults" => types.size,
        "Resources" => types
      }
      render_scim(payload)
    end

    private

    def user_resource_type
      prefix = DeviseScim.configuration.route_prefix
      {
        "schemas" => [RESOURCE_TYPE_SCHEMA],
        "id" => "User",
        "name" => "User",
        "endpoint" => "#{prefix}/Users",
        "schema" => Scim::USER_SCHEMA
      }
    end

    def group_resource_type
      prefix = DeviseScim.configuration.route_prefix
      {
        "schemas" => [RESOURCE_TYPE_SCHEMA],
        "id" => "Group",
        "name" => "Group",
        "endpoint" => "#{prefix}/Groups",
        "schema" => Scim::GROUP_SCHEMA
      }
    end
  end
end
