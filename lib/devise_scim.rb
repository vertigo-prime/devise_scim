# frozen_string_literal: true

require_relative "devise_scim/version"
require_relative "devise_scim/configuration"
require_relative "devise_scim/engine" if defined?(Rails)

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
