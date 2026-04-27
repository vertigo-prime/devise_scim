# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.shared_examples "SCIM discovery endpoints" do |_options = {}|
  include DeviseScim::RSpec::ScimHelpers

  let(:_scim_test_token) { "scim-test-token-#{SecureRandom.hex(8)}" }
  let(:_scim_headers)    { scim_auth_headers(_scim_test_token) }

  before do
    DeviseScim.configure do |c|
      c.tenancy     = :single
      c.auth_method = :token
      c.token       = _scim_test_token
    end
  end

  after { DeviseScim.reset_configuration! }

  # ── ServiceProviderConfig ────────────────────────────────────────────────────

  describe "GET /ServiceProviderConfig" do
    it "returns 200 with the correct schema" do
      get "#{scim_prefix}/ServiceProviderConfig", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      expect(body["schemas"]).to include("urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig")
    end

    it "advertises patch support" do
      get "#{scim_prefix}/ServiceProviderConfig", headers: _scim_headers
      body = scim_json(response.body)
      expect(body.dig("patch", "supported")).to be(true)
    end

    it "advertises filter support" do
      get "#{scim_prefix}/ServiceProviderConfig", headers: _scim_headers
      body = scim_json(response.body)
      expect(body.dig("filter", "supported")).to be(true)
    end

    it "sets Content-Type to application/scim+json" do
      get "#{scim_prefix}/ServiceProviderConfig", headers: _scim_headers
      expect(response.content_type).to include("application/scim+json")
    end
  end

  # ── Schemas ──────────────────────────────────────────────────────────────────

  describe "GET /Schemas" do
    it "returns 200 with the User schema" do
      get "#{scim_prefix}/Schemas", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      ids = body["Resources"].map { |r| r["id"] }
      expect(ids).to include(DeviseScim::Scim::USER_SCHEMA)
    end

    context "with groups enabled" do
      before { DeviseScim.configure { |c| c.enable_groups = true } }

      it "includes the Group schema" do
        get "#{scim_prefix}/Schemas", headers: _scim_headers
        body = scim_json(response.body)
        ids = body["Resources"].map { |r| r["id"] }
        expect(ids).to include(DeviseScim::Scim::GROUP_SCHEMA)
      end
    end
  end

  # ── ResourceTypes ────────────────────────────────────────────────────────────

  describe "GET /ResourceTypes" do
    it "returns 200 with the User resource type" do
      get "#{scim_prefix}/ResourceTypes", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      names = body["Resources"].map { |r| r["name"] }
      expect(names).to include("User")
    end

    context "with groups enabled" do
      before { DeviseScim.configure { |c| c.enable_groups = true } }

      it "includes the Group resource type" do
        get "#{scim_prefix}/ResourceTypes", headers: _scim_headers
        body = scim_json(response.body)
        names = body["Resources"].map { |r| r["name"] }
        expect(names).to include("Group")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
