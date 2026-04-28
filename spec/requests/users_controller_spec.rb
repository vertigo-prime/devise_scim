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

  describe "POST /scim/v2/Users with externalId" do
    let(:payload) do
      {
        "schemas" => [DeviseScim::Scim::USER_SCHEMA],
        "userName" => "uid-user@example.com",
        "externalId" => "ext-abc"
      }
    end

    it "stores scim_uid and finds user by uid on subsequent create" do
      post "/scim/v2/Users", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(User.last.scim_uid).to eq("ext-abc")

      post "/scim/v2/Users", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:conflict)
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

    it "patches email via userName path" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "path" => "userName", "value" => "new@example.com" }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq("new@example.com")
    end

    it "patches email via emails path" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{
          "op" => "replace", "path" => "emails",
          "value" => [{ "value" => "emails@example.com", "primary" => true }]
        }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq("emails@example.com")
    end

    it "patches name.givenName (no-op when column absent)" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "path" => "name.givenName", "value" => "Bob" }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "patches name.familyName (no-op when column absent)" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "path" => "name.familyName", "value" => "Smith" }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "applies valuemap patch (operation without path)" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "value" => { "active" => false } }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.scim_active).to be(false)
    end

    it "applies valuemap patch with userName" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "value" => { "userName" => "vm@example.com" } }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.email).to eq("vm@example.com")
    end

    it "applies valuemap patch with name (no-op when columns absent)" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "value" => { "name" => { "givenName" => "Bob", "familyName" => "Smith" } } }]
      }
      patch "/scim/v2/Users/#{user.id}", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:ok)
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

  context "multi-tenant" do
    let(:tenant) { DeviseScim::ScimTenant.create!(name: "Acme", auth_method: "token", active: true) }
    let(:mt_token) { "mt-token" }
    let(:mt_headers) { { "Authorization" => "Bearer #{mt_token}", "Content-Type" => "application/json" } }

    before do
      DeviseScim.configure do |c|
        c.tenancy     = :multi
        c.auth_method = :token
      end
      allow(DeviseScim::ScimTenant).to receive(:authenticate_token).with(mt_token).and_return(tenant)
    end

    let(:payload) { { "schemas" => [DeviseScim::Scim::USER_SCHEMA], "userName" => "mt@example.com" } }

    describe "GET /scim/v2/Users" do
      it "returns only users provisioned to this tenant" do
        user = User.create!(email: "mt@example.com")
        DeviseScim::ScimTenantUser.create!(scim_tenant_id: tenant.id, user_id: user.id,
                                           active: true, provisioned_at: Time.current)
        other_user = User.create!(email: "other@example.com")

        get "/scim/v2/Users", headers: mt_headers
        parsed = JSON.parse(response.body)
        emails = parsed["Resources"].map { |u| u["userName"] }
        expect(emails).to include("mt@example.com")
        expect(emails).not_to include(other_user.email)
      end
    end

    describe "POST /scim/v2/Users" do
      it "creates a new user and assigns to tenant" do
        expect do
          post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        end.to change(User, :count).by(1).and change(DeviseScim::ScimTenantUser, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it "returns 409 when user is already active in this tenant" do
        user = User.create!(email: "mt@example.com")
        DeviseScim::ScimTenantUser.create!(scim_tenant_id: tenant.id, user_id: user.id,
                                           active: true, provisioned_at: Time.current)

        post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        expect(response).to have_http_status(:conflict)
      end

      it "claims an existing user not yet in any tenant" do
        User.create!(email: "mt@example.com")

        expect do
          post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        end.to change(DeviseScim::ScimTenantUser, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(DeviseScim::ScimTenantUser.last.scim_claimed_at).not_to be_nil
      end

      it "allows assigning user to multiple tenants when user_exclusivity is :multiple" do
        other_tenant = DeviseScim::ScimTenant.create!(name: "Other", auth_method: "token", active: true)
        user = User.create!(email: "mt@example.com")
        DeviseScim::ScimTenantUser.create!(scim_tenant_id: other_tenant.id, user_id: user.id,
                                           active: true, provisioned_at: Time.current)

        DeviseScim.configure { |c| c.user_exclusivity = :multiple }
        post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        expect(response).to have_http_status(:created)
        expect(DeviseScim::ScimTenantUser.where(user_id: user.id).count).to eq(2)
      end

      it "returns 409 when user belongs to another tenant and exclusivity_conflict is :error" do
        other_tenant = DeviseScim::ScimTenant.create!(name: "Other", auth_method: "token", active: true)
        user = User.create!(email: "mt@example.com")
        DeviseScim::ScimTenantUser.create!(scim_tenant_id: other_tenant.id, user_id: user.id,
                                           active: true, provisioned_at: Time.current)

        DeviseScim.configure do |c|
          c.user_exclusivity = :one_to_one
          c.exclusivity_conflict = :error
        end
        post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        expect(response).to have_http_status(:conflict)
      end

      it "reassigns user from another tenant when exclusivity_conflict is :reassign" do
        other_tenant = DeviseScim::ScimTenant.create!(name: "Other", auth_method: "token", active: true)
        user = User.create!(email: "mt@example.com")
        old_join = DeviseScim::ScimTenantUser.create!(scim_tenant_id: other_tenant.id, user_id: user.id,
                                                      active: true, provisioned_at: Time.current)

        DeviseScim.configure do |c|
          c.user_exclusivity = :one_to_one
          c.exclusivity_conflict = :reassign
        end
        post "/scim/v2/Users", params: payload.to_json, headers: mt_headers
        expect(response).to have_http_status(:created)
        expect(old_join.reload.active).to be(false)
      end
    end

    describe "DELETE /scim/v2/Users/:id" do
      it "deactivates the tenant-user join record" do
        user = User.create!(email: "bye@example.com", scim_source: "scim")
        stu = DeviseScim::ScimTenantUser.create!(scim_tenant_id: tenant.id, user_id: user.id,
                                                 active: true, provisioned_at: Time.current)

        delete "/scim/v2/Users/#{user.id}", headers: mt_headers
        expect(response).to have_http_status(:no_content)
        expect(stu.reload.active).to be(false)
      end
    end
  end
end
