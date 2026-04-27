# frozen_string_literal: true

module DeviseScim
  module Auth
    class OauthStrategy < BaseStrategy
      def authenticate(env)
        unless defined?(Doorkeeper)
          raise ConfigurationError,
                "auth_method :oauth requires the doorkeeper gem. Add `gem 'doorkeeper'` to your Gemfile."
        end

        raw = extract_token(env)
        return nil unless raw

        access_token = Doorkeeper::AccessToken.by_token(raw)
        return nil unless access_token&.accessible?

        config = DeviseScim.configuration

        if config.tenancy == :multi
          config.tenant_model.constantize.find_by(doorkeeper_application_id: access_token.application_id)
        else
          :ok
        end
      end
    end
  end
end
