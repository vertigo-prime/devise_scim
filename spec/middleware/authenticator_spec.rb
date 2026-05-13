# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Middleware::Authenticator do
  let(:inner_app) { ->(_env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(inner_app) }

  after { DeviseScim.reset_configuration! }

  def call(path: "/scim/v2/Users", token: nil)
    env = Rack::MockRequest.env_for(path)
    env["HTTP_AUTHORIZATION"] = "Bearer #{token}" if token
    middleware.call(env)
  end

  context "non-SCIM path" do
    it "passes through without auth check" do
      status, = call(path: "/users/sign_in")
      expect(status).to eq(200)
    end
  end

  context "single-tenant token auth" do
    before do
      DeviseScim.configure do |c|
        c.tenancy = :single
        c.auth_method = :token
        c.token = "s3cr3t"
      end
    end

    it "returns 401 for missing token" do
      status, headers, body = call
      expect(status).to eq(401)
      expect(headers["Content-Type"]).to eq("application/scim+json")
      parsed = JSON.parse(body.first)
      expect(parsed["status"]).to eq("401")
      expect(parsed["schemas"]).to include("urn:ietf:params:scim:api:messages:2.0:Error")
    end

    it "returns 401 for wrong token" do
      status, = call(token: "wrong")
      expect(status).to eq(401)
    end

    it "passes through with correct token" do
      status, = call(token: "s3cr3t")
      expect(status).to eq(200)
    end

    it "does not set devise_scim.tenant in single-tenant mode" do
      captured_env = nil
      app = lambda { |env|
        captured_env = env
        [200, {}, []]
      }
      DeviseScim::Middleware::Authenticator.new(app).call(
        Rack::MockRequest.env_for("/scim/v2/Users").merge("HTTP_AUTHORIZATION" => "Bearer s3cr3t")
      )
      expect(captured_env["devise_scim.tenant"]).to be_nil
    end
  end

  context "oauth auth_method" do
    before do
      DeviseScim.configure do |c|
        c.tenancy = :single
        c.auth_method = :oauth
      end
      allow_any_instance_of(DeviseScim::Auth::OauthStrategy)
        .to receive(:authenticate).and_return(:ok)
    end

    it "delegates to OauthStrategy" do
      expect(DeviseScim::Auth::OauthStrategy).to receive(:new).and_call_original
      status, = call(token: "doorkeeper-token")
      expect(status).to eq(200)
    end
  end

  context "multi-tenant token auth" do
    let(:tenant) { DeviseScim::ScimTenant.new }

    before do
      DeviseScim.configure do |c|
        c.tenancy = :multi
        c.auth_method = :token
      end
      allow(DeviseScim::ScimTenant).to receive(:authenticate_token).and_return(tenant)
    end

    it "returns 401 when no tenant matches" do
      allow(DeviseScim::ScimTenant).to receive(:authenticate_token).and_return(nil)
      status, = call(token: "bad")
      expect(status).to eq(401)
    end

    it "sets devise_scim.tenant and passes through" do
      captured_env = nil
      app = lambda { |env|
        captured_env = env
        [200, {}, []]
      }
      DeviseScim::Middleware::Authenticator.new(app).call(
        Rack::MockRequest.env_for("/scim/v2/Users").merge("HTTP_AUTHORIZATION" => "Bearer valid")
      )
      expect(captured_env["devise_scim.tenant"]).to eq(tenant)
    end
  end
end
