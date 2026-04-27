# frozen_string_literal: true

module DeviseScim
  class Engine < ::Rails::Engine
    isolate_namespace DeviseScim

    initializer "devise_scim.middleware" do |app|
      app.middleware.use DeviseScim::Middleware::Authenticator
    end

    config.after_initialize do
      DeviseScim.configuration.validate!
    end
  end
end
