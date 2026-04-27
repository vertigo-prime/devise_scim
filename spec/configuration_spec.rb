# frozen_string_literal: true

require "spec_helper"
require "devise_scim"

RSpec.describe DeviseScim::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it { expect(config.route_prefix).to eq("/scim/v2") }
    it { expect(config.tenancy).to eq(:single) }
    it { expect(config.auth_method).to eq(:token) }
    it { expect(config.devise_model).to eq("User") }
    it { expect(config.enable_groups).to be(false) }
    it { expect(config.soft_delete).to be(true) }
    it { expect(config.deprovision_manual_users).to be(false) }
    it { expect(config.user_exclusivity).to eq(:multiple) }
    it { expect(config.exclusivity_conflict).to eq(:error) }
    it { expect(config.adapter).to be_nil }
    it { expect(config.tenant_model).to eq("DeviseScim::ScimTenant") }
  end

  describe "#validate!" do
    it "passes with all defaults" do
      expect { config.validate! }.not_to raise_error
    end

    it "passes with tenancy :multi" do
      config.tenancy = :multi
      expect { config.validate! }.not_to raise_error
    end

    it "raises on unknown tenancy" do
      config.tenancy = :bad
      expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /tenancy/)
    end

    it "raises on unknown auth_method" do
      config.auth_method = :magic
      expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /auth_method/)
    end

    it "raises on unknown deprovision_manual_users" do
      config.deprovision_manual_users = :maybe
      expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /deprovision_manual_users/)
    end

    it "raises on unknown user_exclusivity" do
      config.user_exclusivity = :none
      expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /user_exclusivity/)
    end

    it "raises on unknown exclusivity_conflict" do
      config.exclusivity_conflict = :ignore
      expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /exclusivity_conflict/)
    end

    context "when auth_method is :oauth" do
      before { config.auth_method = :oauth }

      it "raises if Doorkeeper is not available" do
        hide_const("Doorkeeper")
        expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /doorkeeper/)
      end

      it "passes when Doorkeeper is available" do
        stub_const("Doorkeeper", Module.new)
        expect { config.validate! }.not_to raise_error
      end
    end

    context "when tenancy is :single and user_exclusivity is :one_to_one" do
      it "raises" do
        config.tenancy = :single
        config.user_exclusivity = :one_to_one
        expect { config.validate! }.to raise_error(DeviseScim::ConfigurationError, /one_to_one/)
      end
    end

    context "tenant_model" do
      it "accepts arbitrary string in multi-tenant mode" do
        config.tenancy = :multi
        config.tenant_model = "Org"
        expect { config.validate! }.not_to raise_error
      end

      it "raises when customized in single-tenant mode" do
        config.tenancy = :single
        config.tenant_model = "Org"
        expect { config.validate! }.to raise_error(
          DeviseScim::ConfigurationError, /tenant_model is only applicable in multi-tenant mode/
        )
      end

      it "passes when default value is set in single-tenant mode" do
        config.tenancy = :single
        config.tenant_model = "DeviseScim::ScimTenant"
        expect { config.validate! }.not_to raise_error
      end
    end
  end
end

RSpec.describe DeviseScim do
  after { described_class.reset_configuration! }

  describe ".configure" do
    it "yields configuration" do
      described_class.configure { |c| c.route_prefix = "/api/scim" }
      expect(described_class.configuration.route_prefix).to eq("/api/scim")
    end
  end

  describe ".reset_configuration!" do
    it "restores defaults" do
      described_class.configure { |c| c.route_prefix = "/other" }
      described_class.reset_configuration!
      expect(described_class.configuration.route_prefix).to eq("/scim/v2")
    end
  end
end
