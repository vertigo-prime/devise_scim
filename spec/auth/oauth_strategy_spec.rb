# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Auth::OauthStrategy do
  subject(:strategy) { described_class.new }

  after { DeviseScim.reset_configuration! }

  def env_with(token: nil)
    env = {}
    env["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    env
  end

  context "when Doorkeeper is not loaded" do
    before do
      hide_const("Doorkeeper") if defined?(Doorkeeper)
    end

    it "raises ConfigurationError" do
      expect { strategy.authenticate(env_with(token: "t")) }
        .to raise_error(DeviseScim::ConfigurationError, /doorkeeper/)
    end
  end

  context "when Doorkeeper is available" do
    let(:access_token) { instance_double("Doorkeeper::AccessToken", accessible?: true, application_id: 7) }

    before do
      stub_const("Doorkeeper", Module.new)
      stub_const("Doorkeeper::AccessToken", Class.new)
      allow(Doorkeeper::AccessToken).to receive(:by_token).and_return(access_token)
    end

    context "single-tenant" do
      before do
        DeviseScim.configure do |c|
          c.tenancy = :single
          c.auth_method = :oauth
        end
      end

      it "returns :ok for a valid access token" do
        expect(strategy.authenticate(env_with(token: "valid"))).to eq(:ok)
      end

      it "returns nil when token not found" do
        allow(Doorkeeper::AccessToken).to receive(:by_token).and_return(nil)
        expect(strategy.authenticate(env_with(token: "bad"))).to be_nil
      end

      it "returns nil when token is not accessible" do
        allow(access_token).to receive(:accessible?).and_return(false)
        expect(strategy.authenticate(env_with(token: "expired"))).to be_nil
      end

      it "returns nil with no Authorization header" do
        expect(strategy.authenticate({})).to be_nil
      end
    end

    context "multi-tenant" do
      let(:tenant) { instance_double(DeviseScim::ScimTenant) }

      before do
        DeviseScim.configure do |c|
          c.tenancy = :multi
          c.auth_method = :oauth
        end
        allow(DeviseScim::ScimTenant).to receive(:find_by)
          .with(doorkeeper_application_id: 7)
          .and_return(tenant)
      end

      it "returns the tenant resolved via application_id" do
        expect(strategy.authenticate(env_with(token: "valid"))).to eq(tenant)
      end

      it "returns nil when no tenant found for application" do
        allow(DeviseScim::ScimTenant).to receive(:find_by).and_return(nil)
        expect(strategy.authenticate(env_with(token: "valid"))).to be_nil
      end
    end
  end
end
