# frozen_string_literal: true

require "bcrypt"
require "securerandom"

module DeviseScim
  module Concerns
    module ScimTenant
      extend ActiveSupport::Concern

      included do
        validates :auth_method, inclusion: { in: %w[token oauth] }
        validate :validate_label_column_presence
      end

      class_methods do
        def authenticate_token(raw_token)
          where(auth_method: "token", active: true).find do |record|
            BCrypt::Password.new(record.token_digest).is_password?(raw_token)
          rescue BCrypt::Errors::InvalidHash
            false
          end
        end

        def scim_tenant_label_column
          :name
        end
      end

      def rotate_token!
        raw = SecureRandom.hex(32)
        update!(token_digest: BCrypt::Password.create(raw))
        raw
      end

      def scim_active?
        active
      end

      private

      def validate_label_column_presence
        col = self.class.scim_tenant_label_column
        errors.add(col, :blank) if send(col).blank?
      end
    end
  end
end
