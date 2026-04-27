# frozen_string_literal: true

module DeviseScim
  module Middleware
    class Authenticator
      SCIM_CONTENT_TYPE = "application/scim+json"

      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless scim_path?(env["PATH_INFO"])

        result = build_strategy.authenticate(env)

        if result.nil?
          unauthorized_response(env)
        else
          env["devise_scim.tenant"] = result unless result == :ok
          @app.call(env)
        end
      end

      private

      def scim_path?(path)
        path.start_with?(DeviseScim.configuration.route_prefix)
      end

      def build_strategy
        if DeviseScim.configuration.auth_method == :oauth
          Auth::OauthStrategy.new
        else
          Auth::TokenStrategy.new
        end
      end

      def unauthorized_response(env)
        # Prevent Warden from intercepting the 401 and attempting its failure app.
        env["warden"].custom_failure! if env["warden"].respond_to?(:custom_failure!)
        body = {
          schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
          status: "401",
          detail: "Unauthorized"
        }.to_json
        [401, { "Content-Type" => SCIM_CONTENT_TYPE }, [body]]
      end
    end
  end
end
