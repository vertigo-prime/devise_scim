# frozen_string_literal: true

require_relative "devise_scim/version"
require_relative "devise_scim/configuration"
if defined?(Rails)
  require_relative "devise_scim/concerns/scim_tenant"
  require_relative "devise_scim/models/scim_tenant"
  require_relative "devise_scim/models/scim_tenant_user"
  require_relative "devise_scim/engine"
end

module DeviseScim
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
