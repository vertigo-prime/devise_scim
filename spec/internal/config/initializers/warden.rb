# frozen_string_literal: true

# Devise 5.x only adds Warden::Manager when devise_for is used.
# In the test app we skip devise_for, so we add Warden here so that
# Devise::RouteSet#finalize! can find warden_config without raising.
require "warden"

Rails.application.config.middleware.use Warden::Manager do |manager|
  Devise.warden_config = manager if defined?(Devise)
end
