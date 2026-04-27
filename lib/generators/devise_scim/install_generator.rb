# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module DeviseScim
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      argument :model_name, type: :string, default: "User",
                            desc: "Devise model to add SCIM fields to (e.g. User)"

      class_option :multi_tenant, type: :boolean, default: false,
                                  desc: "Generate multi-tenant migrations"
      class_option :oauth, type: :boolean, default: false,
                           desc: "Configure OAuth 2.0 client-credentials auth"
      class_option :tenant_model, type: :string, default: nil,
                                  desc: "Existing model to use as the SCIM tenant (e.g. Org). " \
                                        "Omit to use the built-in DeviseScim::ScimTenant."

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def preflight_check
        return unless needs_doorkeeper?

        unless doorkeeper_in_gemfile?
          say_status :error, "Doorkeeper gem not found in Gemfile.", :red
          say "  Add `gem 'doorkeeper', '~> 5.6'` to your Gemfile and run `bundle install`.", :red
          raise Thor::Error, "Aborting: Doorkeeper required for #{doorkeeper_reason}."
        end

        return if doorkeeper_installed?

        unless yes?("Doorkeeper not yet installed. Run `rails g doorkeeper:install` now?")
          raise Thor::Error, "Aborting. Run `rails g doorkeeper:install` before proceeding."
        end

        generate "doorkeeper:install"
      end

      def copy_user_migration
        migration_template(
          "add_scim_to_users.rb.tt",
          "db/migrate/add_scim_to_#{table_name}.rb"
        )
      end

      def copy_tenant_migrations
        return unless options[:multi_tenant]

        if options[:tenant_model]
          migration_template "add_scim_to_tenant.rb.tt",
                             "db/migrate/add_scim_to_#{tenant_table_name}.rb"
        else
          migration_template "create_scim_tenants.rb.tt", "db/migrate/create_scim_tenants.rb"
        end
        migration_template "create_scim_tenant_users.rb.tt", "db/migrate/create_scim_tenant_users.rb"
      end

      def copy_initializer
        template "devise_scim.rb.tt", "config/initializers/devise_scim.rb"
      end

      private

      def needs_doorkeeper?
        options[:oauth] || options[:multi_tenant]
      end

      def doorkeeper_reason
        options[:multi_tenant] ? "--multi-tenant mode" : "--oauth auth"
      end

      def doorkeeper_in_gemfile?
        gemfile = File.join(destination_root, "Gemfile")
        File.exist?(gemfile) && File.read(gemfile).include?("doorkeeper")
      end

      def doorkeeper_installed?
        Dir[File.join(destination_root, "db/migrate/*doorkeeper*")].any? ||
          Dir[File.join(destination_root, "db/migrate/*create_doorkeeper_tables*")].any?
      end

      def table_name
        model_name.underscore.pluralize
      end

      def tenant_table_name
        options[:tenant_model] ? options[:tenant_model].underscore.pluralize : "scim_tenants"
      end

      def tenant_ref_name
        options[:tenant_model] ? options[:tenant_model].underscore : "scim_tenant"
      end

      def tenant_fk_column
        options[:tenant_model] ? "#{options[:tenant_model].underscore}_id" : "scim_tenant_id"
      end

      def migration_version
        "[#{ActiveRecord::Migration.current_version}]"
      end

      def scim_raw_type
        adapter = ActiveRecord::Base.connection.adapter_name.downcase
        adapter.include?("postgresql") ? "jsonb" : "text"
      rescue StandardError
        "text"
      end
    end
  end
end
