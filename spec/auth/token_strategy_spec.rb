# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Auth::TokenStrategy do
  subject(:strategy) { described_class.new }

  after { DeviseScim.reset_configuration! }

  def env_with(token: nil)
    env = {}
    env["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    env
  end

  context "single-tenant" do
    before do
      DeviseScim.configure do |c|
        c.tenancy = :single
        c.auth_method = :token
        c.token = "correct_token"
      end
    end

    it "returns :ok for the correct token" do
      expect(strategy.authenticate(env_with(token: "correct_token"))).to eq(:ok)
    end

    it "returns nil for a wrong token" do
      expect(strategy.authenticate(env_with(token: "wrong"))).to be_nil
    end

    it "returns nil with no Authorization header" do
      expect(strategy.authenticate({})).to be_nil
    end

    it "returns nil when config.token is nil" do
      DeviseScim.configuration.token = nil
      expect(strategy.authenticate(env_with(token: "any"))).to be_nil
    end
  end

  context "multi-tenant" do
    let(:tenant) { instance_double(DeviseScim::ScimTenant) }

    before do
      DeviseScim.configure do |c|
        c.tenancy = :multi
        c.auth_method = :token
      end
      allow(DeviseScim::ScimTenant).to receive(:authenticate_token).and_return(tenant)
    end

    it "returns the tenant record on a valid token" do
      expect(strategy.authenticate(env_with(token: "rawtoken"))).to eq(tenant)
    end

    it "returns nil when no matching tenant" do
      allow(DeviseScim::ScimTenant).to receive(:authenticate_token).and_return(nil)
      expect(strategy.authenticate(env_with(token: "bad"))).to be_nil
    end

    it "returns nil with no Authorization header" do
      expect(strategy.authenticate({})).to be_nil
    end
  end
end
