# frozen_string_literal: true

module DeviseScim
  module Auth
    class BaseStrategy
      private

      def extract_token(env)
        auth = env["HTTP_AUTHORIZATION"]
        return nil unless auth&.start_with?("Bearer ")

        auth.delete_prefix("Bearer ").strip
      end
    end
  end
end
