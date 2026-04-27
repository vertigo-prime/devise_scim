# frozen_string_literal: true

module DeviseScim
  class ServiceProviderController < ApplicationController
    def show
      render_scim(service_provider_config)
    end

    private

    def service_provider_config
      {
        "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig"],
        "patch" => { "supported" => true },
        "bulk" => { "supported" => false, "maxOperations" => 0, "maxPayloadSize" => 0 },
        "filter" => { "supported" => true, "maxResults" => 200 },
        "changePassword" => { "supported" => false },
        "sort" => { "supported" => false },
        "etag" => { "supported" => false },
        "authenticationSchemes" => auth_schemes
      }
    end

    def auth_schemes
      if DeviseScim.configuration.auth_method == :oauth
        [{ "type" => "oauthbearertoken", "name" => "OAuth Bearer Token",
           "description" => "OAuth2 client_credentials grant" }]
      else
        [{ "type" => "oauthbearertoken", "name" => "Bearer Token",
           "description" => "Static bearer token authentication" }]
      end
    end
  end
end
