# frozen_string_literal: true

require "rails/generators"

module DeviseScim
  module Generators
    class AdapterGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a pre-filled ScimAdapter in app/scim/application_scim_adapter.rb"

      def copy_adapter
        template "application_scim_adapter.rb.tt", "app/scim/application_scim_adapter.rb"
      end
    end
  end
end
