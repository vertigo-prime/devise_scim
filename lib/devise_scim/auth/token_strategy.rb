# frozen_string_literal: true

require "active_support/security_utils"

module DeviseScim
  module Auth
    class TokenStrategy < BaseStrategy
      def authenticate(env)
        raw = extract_token(env)
        return nil unless raw

        config = DeviseScim.configuration

        if config.tenancy == :multi
          config.tenant_model.constantize.authenticate_token(raw)
        else
          return nil if config.token.nil?
          return nil unless ActiveSupport::SecurityUtils.secure_compare(raw, config.token)

          :ok
        end
      end
    end
  end
end
