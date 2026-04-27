# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DeviseScim Users", type: :request do
  let(:token) { "test-scim-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  before do
    DeviseScim.configure do |c|
      c.tenancy = :single
      c.auth_method = :token
      c.token = token
    end
  end

  after { DeviseScim.reset_configuration! }

  def scim_json(body)
    JSON.parse(body)
  end

  describe "GET /scim/v2/Users" do
    before { User.create!(email: "alice@example.com") }

    it "returns 200 with ListResponse" do
      get "/scim/v2/Users", headers: headers
      expect(response).to have_http_status(:ok)
      parsed = scim_json(response.body)
      expect(parsed["schemas"]).to include(DeviseScim::Scim::LIST_RESPONSE_SCHEMA)
      expect(parsed["totalResults"]).to eq(1)
      expect(parsed["Resources"].first["userName"]).to eq("alice@example.com")
    end

    it "sets Content-Type to application/scim+json" do
      get "/scim/v2/Users", headers: headers
      expect(response.content_type).to include("application/scim+json")
    end

    context "with filter" do
      before { User.create!(email: "bob@example.com") }

      it "filters by userName eq" do
        get '/scim/v2/Users?filter=userName eq "alice@example.com"', headers: headers
        parsed = scim_json(response.body)
        expect(parsed["totalResults"]).to eq(1)
        expect(parsed["Resources"].first["userName"]).to eq("alice@example.com")
      end

      it "returns 400 for invalid filter" do
        get "/scim/v2/Users?filter=!!!bad", headers: headers
        expect(response).to have_http_status(:bad_request)
        parsed = scim_json(response.body)
        expect(parsed["scimType"]).to eq("invalidFilter")
      end
    end
  end

  describe "POST /scim/v2/Users" do
    let(:payload) do
      {
        "schemas" => [DeviseScim::Scim::USER_SCHEMA],
        "userName" => "newuser@example.com",
        "name" => { "givenName" => "New", "familyName" => "User" },
        "emails" => [{ "value" => "newuser@example.com", "primary" => true }]
      }
    end

    it "creates a user and returns 201" do
      expect do
        post "/scim/v2/Users", params: payload.to_json, headers: headers
      end.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
      parsed = scim_json(response.body)
      expect(parsed["userName"]).to eq("newuser@example.com")
    end

    it "sets scim_source to 'scim'" do
      post "/scim/v2/Users", params: payload.to_json, headers: headers
      expect(User.last.scim_source).to eq("scim")
    end

    it "returns 409 when user already exists" do
      User.create!(email: "newuser@example.com", scim_source: "scim")
      post "/scim/v2/Users", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:conflict)
    end

    it "re-provisions a deprovisioned user" do
      existing = User.create!(email: "newuser@example.com", scim_source: "scim", scim_active: false)
      post "/scim/v2/Users", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(existing.reload.scim_active).to be(true)
    end
  end

  describe "GET /scim/v2/Users/:id" do
    let!(:user) { User.create!(email: "alice@example.com") }

    it "returns the user" do
      get "/scim/v2/Users/#{user.id}", headers: headers
      expect(response).to have_http_status(:ok)
      parsed = scim_json(response.body)
      expect(parsed["id"]).to eq(user.id.to_s)
      expect(parsed["userName"]).to eq("alice@example.com")
    end

    it "returns 404 for unknown id" do
      get "/scim/v2/Users/999999", headers: headers
      expect(response).to have_http_status(:not_found)
      parsed = scim_json(response.body)
      expect(parsed["status"]).to eq("404")
    end
  end

  describe "PUT /scim/v2/Users/:id" do
    let!(:user) { User.create!(email: "old@example.com") }
    let(:payload) do
      {
        "schemas" => [DeviseScim::Scim::USER_SCHEMA],
        "userName" => "updated@example.com"
      }
    end

    it "updates the user and returns 200" do
      put "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq("updated@example.com")
    end
  end

  describe "PATCH /scim/v2/Users/:id" do
    let!(:user) { User.create!(email: "alice@example.com", scim_active: true) }

    it "applies patch ops" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "path" => "active", "value" => false }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.scim_active).to be(false)
    end
  end

  describe "DELETE /scim/v2/Users/:id" do
    let!(:user) { User.create!(email: "alice@example.com", scim_source: "scim") }

    it "deactivates and returns 204" do
      delete "/scim/v2/Users/#{user.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(user.reload.scim_active).to be(false)
      expect(user.reload.scim_deprovisioned_at).not_to be_nil
    end

    context "deprovision_manual_users: false (default)" do
      let!(:manual_user) { User.create!(email: "manual@example.com", scim_source: nil) }

      it "returns 200 and skips deprovision" do
        delete "/scim/v2/Users/#{manual_user.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(manual_user.reload.scim_active).to be(true)
      end
    end

    context "deprovision_manual_users: :error" do
      before { DeviseScim.configure { |c| c.deprovision_manual_users = :error } }

      let!(:manual_user) { User.create!(email: "manual@example.com", scim_source: nil) }

      it "returns 409" do
        delete "/scim/v2/Users/#{manual_user.id}", headers: headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "authentication" do
    it "returns 401 for missing token" do
      get "/scim/v2/Users"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for wrong token" do
      get "/scim/v2/Users", headers: { "Authorization" => "Bearer wrong" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
