# frozen_string_literal: true

module DeviseScim
  class Configuration
    VALID_TENANCY               = %i[single multi].freeze
    VALID_AUTH_METHODS          = %i[token oauth].freeze
    VALID_DEPROVISION           = [false, true, :error].freeze
    VALID_USER_EXCLUSIVITY      = %i[multiple one_to_one].freeze
    VALID_EXCLUSIVITY_CONFLICT  = %i[error reassign].freeze

    attr_accessor \
      :route_prefix,
      :tenancy,
      :auth_method,
      :token,
      :oauth_client_id,
      :oauth_client_secret,
      :devise_model,
      :enable_groups,
      :soft_delete,
      :deprovision_manual_users,
      :user_exclusivity,
      :exclusivity_conflict,
      :adapter

    def initialize
      @route_prefix             = "/scim/v2"
      @tenancy                  = :single
      @auth_method              = :token
      @token                    = nil
      @oauth_client_id          = nil
      @oauth_client_secret      = nil
      @devise_model             = "User"
      @enable_groups            = false
      @soft_delete              = true
      @deprovision_manual_users = false
      @user_exclusivity         = :multiple
      @exclusivity_conflict     = :error
      @adapter                  = nil
    end

    def validate!
      validate_enum!(:tenancy, tenancy, VALID_TENANCY)
      validate_enum!(:auth_method, auth_method, VALID_AUTH_METHODS)
      validate_enum!(:user_exclusivity, user_exclusivity, VALID_USER_EXCLUSIVITY)
      validate_enum!(:exclusivity_conflict, exclusivity_conflict, VALID_EXCLUSIVITY_CONFLICT)

      unless VALID_DEPROVISION.include?(deprovision_manual_users)
        raise ConfigurationError,
              "deprovision_manual_users must be true, false, or :error; got #{deprovision_manual_users.inspect}"
      end

      if auth_method == :oauth && !doorkeeper_available?
        raise ConfigurationError,
              "auth_method :oauth requires the doorkeeper gem. Add `gem 'doorkeeper'` to your Gemfile."
      end

      return unless tenancy == :single && user_exclusivity == :one_to_one

      raise ConfigurationError,
            "user_exclusivity :one_to_one is only meaningful in multi-tenant mode."
    end

    private

    def validate_enum!(name, value, valid)
      return if valid.include?(value)

      raise ConfigurationError,
            "#{name} must be one of #{valid.inspect}; got #{value.inspect}"
    end

    def doorkeeper_available?
      defined?(Doorkeeper)
    end
  end
end
