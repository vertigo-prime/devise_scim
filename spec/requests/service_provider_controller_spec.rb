# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DeviseScim ServiceProviderConfig", type: :request do
  let(:token) { "test-scim-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  before do
    DeviseScim.configure do |c|
      c.tenancy     = :single
      c.auth_method = :token
      c.token       = token
    end
  end

  after { DeviseScim.reset_configuration! }

  describe "GET /scim/v2/ServiceProviderConfig" do
    it "returns 200 with correct schema" do
      get "/scim/v2/ServiceProviderConfig", headers: headers
      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      expect(parsed["schemas"]).to include("urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig")
    end

    it "includes patch support" do
      get "/scim/v2/ServiceProviderConfig", headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed["patch"]["supported"]).to be(true)
    end

    it "includes filter support" do
      get "/scim/v2/ServiceProviderConfig", headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed["filter"]["supported"]).to be(true)
    end

    it "sets Content-Type to application/scim+json" do
      get "/scim/v2/ServiceProviderConfig", headers: headers
      expect(response.content_type).to include("application/scim+json")
    end
  end
end
