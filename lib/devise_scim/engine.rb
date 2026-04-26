# frozen_string_literal: true

module DeviseScim
  class Engine < ::Rails::Engine
    isolate_namespace DeviseScim

    config.after_initialize do
      DeviseScim.configuration.validate!
    end
  end
end
