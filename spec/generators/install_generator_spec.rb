# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "active_record"
require "rails"
require "rails/generators"
require "rails/generators/active_record"
require "generators/devise_scim/install_generator"

# Minimal AR setup so migration number helpers have a connection.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

RSpec.describe DeviseScim::Generators::InstallGenerator do
  let(:destination) { Dir.mktmpdir("devise_scim_gen_test") }

  after { FileUtils.rm_rf(destination) }

  # opts is a Hash (not string args) — Thor only parses class_options from the
  # second positional arg when instantiated directly.
  def build_gen(args = ["User"], opts = {})
    described_class.new(args, opts, { destination_root: destination, quiet: true })
  end

  def run_gen(args = ["User"], opts = {})
    build_gen(args, opts).invoke_all
  end

  def write_gemfile(content)
    File.write(File.join(destination, "Gemfile"), content)
  end

  def stub_doorkeeper_installed
    FileUtils.mkdir_p File.join(destination, "db/migrate")
    File.write(File.join(destination, "db/migrate/20200101000000_create_doorkeeper_tables.rb"), "")
  end

  def migration_exists?(pattern)
    Dir["#{destination}/db/migrate/*#{pattern}*"].any?
  end

  def migration_content(pattern)
    file = Dir["#{destination}/db/migrate/*#{pattern}*"].first
    file ? File.read(file) : ""
  end

  def initializer_content
    path = File.join(destination, "config/initializers/devise_scim.rb")
    File.exist?(path) ? File.read(path) : ""
  end

  # ── single-tenant, token auth ────────────────────────────────────────────────

  context "single-tenant token auth (default)" do
    before do
      write_gemfile("gem 'devise'")
      run_gen
    end

    it "generates user SCIM migration" do
      expect(migration_exists?("add_scim_to_users")).to be true
    end

    it "does not generate tenant migrations" do
      expect(migration_exists?("scim_tenant")).to be false
    end

    it "includes scim_uid column" do
      expect(migration_content("add_scim_to_users")).to include(":scim_uid")
    end

    it "generates initializer" do
      expect(initializer_content).to include("DeviseScim.configure")
    end

    it "sets devise_model to User" do
      expect(initializer_content).to include('config.devise_model = "User"')
    end

    it "sets tenancy to :single" do
      expect(initializer_content).to include("config.tenancy = :single")
    end
  end

  context "single-tenant with non-default model name" do
    before do
      write_gemfile("gem 'devise'")
      run_gen ["Account"]
    end

    it "generates migration for accounts table" do
      expect(migration_exists?("add_scim_to_accounts")).to be true
    end

    it "uses correct class name" do
      expect(migration_content("add_scim_to_accounts")).to include("AddScimToAccounts")
    end
  end

  # ── single-tenant, oauth ─────────────────────────────────────────────────────

  context "with --oauth, doorkeeper absent from Gemfile" do
    before { write_gemfile("gem 'devise'") }

    it "aborts before generating any files" do
      expect { run_gen ["User"], { oauth: true } }.to raise_error(Thor::Error, /Doorkeeper/)
      expect(migration_exists?("add_scim_to_users")).to be false
    end
  end

  context "with --oauth, doorkeeper present and installed" do
    before do
      write_gemfile("gem 'doorkeeper'")
      stub_doorkeeper_installed
      run_gen ["User"], { oauth: true }
    end

    it "generates user migration" do
      expect(migration_exists?("add_scim_to_users")).to be true
    end

    it "does not generate tenant migrations" do
      expect(migration_exists?("scim_tenant")).to be false
    end
  end

  # ── multi-tenant ─────────────────────────────────────────────────────────────

  context "with --multi-tenant, doorkeeper absent from Gemfile" do
    before { write_gemfile("gem 'devise'") }

    it "aborts before generating any files" do
      expect { run_gen ["User"], { multi_tenant: true } }.to raise_error(Thor::Error, /Doorkeeper/)
      expect(migration_exists?("add_scim_to_users")).to be false
    end
  end

  context "with --multi-tenant, doorkeeper present and installed" do
    before do
      write_gemfile("gem 'doorkeeper'")
      stub_doorkeeper_installed
      run_gen ["User"], { multi_tenant: true }
    end

    it "generates user SCIM migration" do
      expect(migration_exists?("add_scim_to_users")).to be true
    end

    it "generates scim_tenants migration" do
      expect(migration_exists?("create_scim_tenants")).to be true
    end

    it "generates scim_tenant_users migration" do
      expect(migration_exists?("create_scim_tenant_users")).to be true
    end

    it "omits scim_uid from user migration in multi-tenant mode" do
      expect(migration_content("add_scim_to_users")).not_to include(":scim_uid")
    end

    it "includes scim_uid on the join table migration" do
      expect(migration_content("create_scim_tenant_users")).to include(":scim_uid")
    end

    it "sets tenancy to :multi in initializer" do
      expect(initializer_content).to include("config.tenancy = :multi")
    end
  end

  context "initializer interpolates model_name" do
    before do
      write_gemfile("gem 'doorkeeper'")
      stub_doorkeeper_installed
      run_gen ["Account"], { multi_tenant: true }
    end

    it "sets devise_model to Account" do
      expect(initializer_content).to include('config.devise_model = "Account"')
    end

    it "sets tenancy to :multi" do
      expect(initializer_content).to include("config.tenancy = :multi")
    end

    it "contains all 13 config keys" do
      keys = %w[
        route_prefix tenancy devise_model enable_groups soft_delete
        deprovision_manual_users adapter auth_method token
        oauth_client_id oauth_client_secret user_exclusivity exclusivity_conflict
      ]
      keys.each { |k| expect(initializer_content).to include("config.#{k}") }
    end
  end

  # ── multi-tenant with custom tenant model ────────────────────────────────────

  context "with --multi-tenant --tenant-model=Org, doorkeeper present and installed" do
    before do
      write_gemfile("gem 'doorkeeper'")
      stub_doorkeeper_installed
      run_gen ["User"], { multi_tenant: true, tenant_model: "Org" }
    end

    it "skips create_scim_tenants migration" do
      expect(migration_exists?("create_scim_tenants")).to be false
    end

    it "generates add_scim_to_orgs migration with conditional add_column" do
      expect(migration_exists?("add_scim_to_orgs")).to be true
      content = migration_content("add_scim_to_orgs")
      expect(content).to include("column_exists?(:orgs, :token_digest)")
      expect(content).to include("column_exists?(:orgs, :auth_method)")
      expect(content).to include("column_exists?(:orgs, :doorkeeper_application_id)")
    end

    it "generates create_scim_tenant_users with org_id FK column" do
      expect(migration_exists?("create_scim_tenant_users")).to be true
      expect(migration_content("create_scim_tenant_users")).to include("org_id")
    end

    it "sets config.tenant_model in the initializer" do
      expect(initializer_content).to include('config.tenant_model = "Org"')
    end
  end

  context "with --multi-tenant, doorkeeper in Gemfile but not installed, user declines" do
    before { write_gemfile("gem 'doorkeeper'") }

    it "aborts without generating files" do
      gen = build_gen ["User"], { multi_tenant: true }
      allow(gen).to receive(:yes?).and_return(false)

      expect { gen.invoke_all }.to raise_error(Thor::Error)
      expect(migration_exists?("add_scim_to_users")).to be false
    end
  end

  context "with --multi-tenant, doorkeeper in Gemfile but not installed, user accepts" do
    before { write_gemfile("gem 'doorkeeper'") }

    it "generates migrations after user accepts doorkeeper:install" do
      gen = build_gen ["User"], { multi_tenant: true }
      allow(gen).to receive(:yes?).and_return(true)
      allow(gen).to receive(:generate)
      gen.invoke_all

      expect(migration_exists?("add_scim_to_users")).to be true
      expect(migration_exists?("create_scim_tenants")).to be true
    end
  end
end
