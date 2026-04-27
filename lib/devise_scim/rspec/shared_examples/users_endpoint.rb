# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.shared_examples "a SCIM Users endpoint" do |options = {}|
  include DeviseScim::RSpec::ScimHelpers

  let(:_scim_model)      { options[:devise_model] || raise(ArgumentError, "devise_model: is required") }
  let(:_scim_test_token) { "scim-test-token-#{SecureRandom.hex(8)}" }
  let(:_scim_headers)    { scim_auth_headers(_scim_test_token) }
  let(:_scim_email)      { "scim.user@example.com" }

  before do
    DeviseScim.configure do |c|
      c.tenancy     = :single
      c.auth_method = :token
      c.token       = _scim_test_token
    end
  end

  after { DeviseScim.reset_configuration! }

  # ── GET /Users ─────────────────────────────────────────────────────────────

  describe "GET /Users" do
    let!(:_listed_user) { _scim_model.create!(email: _scim_email) }

    it "returns 200 with ListResponse schema" do
      get "#{scim_prefix}/Users", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      expect(body["schemas"]).to include(DeviseScim::Scim::LIST_RESPONSE_SCHEMA)
      expect(body).to have_key("totalResults")
      expect(body).to have_key("Resources")
    end

    it "includes the user in Resources" do
      get "#{scim_prefix}/Users", headers: _scim_headers
      usernames = scim_json(response.body)["Resources"].map { |u| u["userName"] }
      expect(usernames).to include(_scim_email)
    end

    it "sets Content-Type to application/scim+json" do
      get "#{scim_prefix}/Users", headers: _scim_headers
      expect(response.content_type).to include("application/scim+json")
    end

    context "with filter" do
      before { _scim_model.create!(email: "other@example.com") }

      it "filters by userName eq" do
        get "#{scim_prefix}/Users?filter=userName eq \"#{_scim_email}\"", headers: _scim_headers
        body = scim_json(response.body)
        expect(body["totalResults"]).to eq(1)
        expect(body["Resources"].first["userName"]).to eq(_scim_email)
      end

      it "returns 400 with invalidFilter scimType for a bad filter" do
        get "#{scim_prefix}/Users?filter=!!!bad", headers: _scim_headers
        expect(response).to have_http_status(:bad_request)
        body = scim_json(response.body)
        expect(body["scimType"]).to eq("invalidFilter")
      end
    end
  end

  # ── POST /Users ─────────────────────────────────────────────────────────────

  describe "POST /Users" do
    let(:_create_payload) { scim_user_payload(user_name: _scim_email) }

    it "creates a user and returns 201" do
      expect do
        post "#{scim_prefix}/Users", params: _create_payload.to_json, headers: _scim_headers
      end.to change(_scim_model, :count).by(1)
      expect(response).to have_http_status(:created)
      body = scim_json(response.body)
      expect(body["userName"]).to eq(_scim_email)
    end

    it "sets scim_source to 'scim' on the created user" do
      post "#{scim_prefix}/Users", params: _create_payload.to_json, headers: _scim_headers
      user = _scim_model.find_by(email: _scim_email)
      expect(user.scim_source).to eq("scim") if user.respond_to?(:scim_source)
    end

    it "returns 409 when the user already exists and is active" do
      _scim_model.create!(email: _scim_email, scim_source: "scim")
      post "#{scim_prefix}/Users", params: _create_payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:conflict)
    end

    it "re-provisions a deprovisioned SCIM user" do
      existing = _scim_model.create!(email: _scim_email, scim_source: "scim", scim_active: false)
      post "#{scim_prefix}/Users", params: _create_payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:created)
      expect(existing.reload.scim_active).to be(true)
    end
  end

  # ── GET /Users/:id ───────────────────────────────────────────────────────────

  describe "GET /Users/:id" do
    let!(:_shown_user) { _scim_model.create!(email: _scim_email) }

    it "returns the user by id" do
      get "#{scim_prefix}/Users/#{_shown_user.id}", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      expect(body["id"]).to eq(_shown_user.id.to_s)
      expect(body["userName"]).to eq(_scim_email)
    end

    it "returns 404 with SCIM error for an unknown id" do
      get "#{scim_prefix}/Users/0", headers: _scim_headers
      expect(response).to have_http_status(:not_found)
      body = scim_json(response.body)
      expect(body["status"]).to eq("404")
      expect(body["schemas"]).to include(DeviseScim::Scim::ERROR_SCHEMA)
    end
  end

  # ── PUT /Users/:id ───────────────────────────────────────────────────────────

  describe "PUT /Users/:id" do
    let!(:_replaced_user) { _scim_model.create!(email: "old@example.com") }

    it "replaces user attributes and returns 200" do
      payload = scim_user_payload(user_name: "updated@example.com")
      put "#{scim_prefix}/Users/#{_replaced_user.id}", params: payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:ok)
      expect(_replaced_user.reload.email).to eq("updated@example.com")
    end
  end

  # ── PATCH /Users/:id ─────────────────────────────────────────────────────────

  describe "PATCH /Users/:id" do
    let!(:_patched_user) { _scim_model.create!(email: _scim_email, scim_active: true) }

    it "applies a replace op to active" do
      payload = scim_patch_payload(scim_replace_op("active", false))
      patch "#{scim_prefix}/Users/#{_patched_user.id}", params: payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:ok)
      expect(_patched_user.reload.scim_active).to be(false) if _patched_user.respond_to?(:scim_active)
    end

    it "applies a replace op to userName" do
      payload = scim_patch_payload(scim_replace_op("userName", "patched@example.com"))
      patch "#{scim_prefix}/Users/#{_patched_user.id}", params: payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:ok)
      expect(_patched_user.reload.email).to eq("patched@example.com")
    end

    it "applies a remove op without error" do
      payload = scim_patch_payload(scim_remove_op("active"))
      patch "#{scim_prefix}/Users/#{_patched_user.id}", params: payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:ok)
    end
  end

  # ── DELETE /Users/:id ────────────────────────────────────────────────────────

  describe "DELETE /Users/:id" do
    let!(:_scim_sourced_user) { _scim_model.create!(email: _scim_email, scim_source: "scim") }

    it "soft-deactivates the user and returns 204" do
      delete "#{scim_prefix}/Users/#{_scim_sourced_user.id}", headers: _scim_headers
      expect(response).to have_http_status(:no_content)
      reloaded = _scim_sourced_user.reload
      expect(reloaded.scim_active).to be(false) if reloaded.respond_to?(:scim_active)
      expect(reloaded.scim_deprovisioned_at).not_to be_nil if reloaded.respond_to?(:scim_deprovisioned_at)
    end

    context "with deprovision_manual_users: false (default)" do
      let!(:_manual_user) { _scim_model.create!(email: "manual@example.com", scim_source: nil) }

      it "returns 200 and skips deprovisioning the manual user" do
        delete "#{scim_prefix}/Users/#{_manual_user.id}", headers: _scim_headers
        expect(response).to have_http_status(:ok)
        expect(_manual_user.reload.scim_active).to be(true) if _manual_user.respond_to?(:scim_active)
      end
    end

    context "with deprovision_manual_users: :error" do
      before { DeviseScim.configure { |c| c.deprovision_manual_users = :error } }

      let!(:_manual_user) { _scim_model.create!(email: "manual@example.com", scim_source: nil) }

      it "returns 409 for a manually-created user" do
        delete "#{scim_prefix}/Users/#{_manual_user.id}", headers: _scim_headers
        expect(response).to have_http_status(:conflict)
      end
    end
  end

  # ── Re-provisioning ──────────────────────────────────────────────────────────

  describe "re-provisioning" do
    it "POST after DELETE re-enables the deprovisioned user" do
      user = _scim_model.create!(email: _scim_email, scim_source: "scim")
      delete "#{scim_prefix}/Users/#{user.id}", headers: _scim_headers
      expect(response).to have_http_status(:no_content)

      post "#{scim_prefix}/Users",
           params: scim_user_payload(user_name: _scim_email).to_json,
           headers: _scim_headers
      expect(response).to have_http_status(:created)
      expect(user.reload.scim_active).to be(true)
    end
  end

  # ── Authentication ───────────────────────────────────────────────────────────

  describe "authentication" do
    it "returns 401 with SCIM error body when no auth is provided" do
      get "#{scim_prefix}/Users"
      expect(response).to have_http_status(:unauthorized)
      body = scim_json(response.body)
      expect(body["schemas"]).to include(DeviseScim::Scim::ERROR_SCHEMA)
      expect(body["status"]).to eq("401")
    end

    it "returns 401 for an invalid token" do
      get "#{scim_prefix}/Users", headers: scim_auth_headers("invalid-token")
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── Multi-tenant ─────────────────────────────────────────────────────────────

  context "multi-tenant" do
    let!(:_mt_tenant) do
      DeviseScim::ScimTenant.create!(name: "Shared Example Org", auth_method: "token", active: true)
    end
    let(:_mt_token)   { _mt_tenant.rotate_token! }
    let(:_mt_headers) { scim_auth_headers(_mt_token) }

    before do
      _mt_token
      DeviseScim.configure { |c| c.tenancy = :multi }
    end

    it "claims an existing manual user and sets scim_claimed_at on the join record" do
      manual = _scim_model.create!(email: "manual@example.com")
      post "#{scim_prefix}/Users",
           params: scim_user_payload(user_name: "manual@example.com").to_json,
           headers: _mt_headers
      expect(response).to have_http_status(:created)
      join = DeviseScim::ScimTenantUser.find_by(user_id: manual.id)
      expect(join).not_to be_nil
      expect(join.scim_claimed_at).not_to be_nil
    end

    it "returns 404 for a user not assigned to this tenant" do
      other_user = _scim_model.create!(email: "other@example.com")
      get "#{scim_prefix}/Users/#{other_user.id}", headers: _mt_headers
      expect(response).to have_http_status(:not_found)
    end

    context "with user_exclusivity: :one_to_one" do
      let!(:_other_tenant) do
        t = DeviseScim::ScimTenant.create!(name: "Other Org", auth_method: "token", active: true)
        t.rotate_token!
        t
      end

      before { DeviseScim.configure { |c| c.user_exclusivity = :one_to_one } }

      it "returns 409 when user belongs to another tenant (exclusivity_conflict: :error)" do
        DeviseScim.configure { |c| c.exclusivity_conflict = :error }
        existing = _scim_model.create!(email: "taken@example.com")
        DeviseScim::ScimTenantUser.create!(
          scim_tenant_id: _other_tenant.id, user_id: existing.id,
          active: true, provisioned_at: Time.current
        )
        post "#{scim_prefix}/Users",
             params: scim_user_payload(user_name: "taken@example.com").to_json,
             headers: _mt_headers
        expect(response).to have_http_status(:conflict)
      end

      it "reassigns the user when exclusivity_conflict: :reassign" do
        DeviseScim.configure { |c| c.exclusivity_conflict = :reassign }
        existing = _scim_model.create!(email: "taken@example.com")
        old_join = DeviseScim::ScimTenantUser.create!(
          scim_tenant_id: _other_tenant.id, user_id: existing.id,
          active: true, provisioned_at: Time.current
        )
        post "#{scim_prefix}/Users",
             params: scim_user_payload(user_name: "taken@example.com").to_json,
             headers: _mt_headers
        expect(response).to have_http_status(:created)
        expect(old_join.reload.active).to be(false)
        new_join = DeviseScim::ScimTenantUser.find_by(user_id: existing.id, scim_tenant_id: _mt_tenant.id)
        expect(new_join).not_to be_nil
        expect(new_join.active).to be(true)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
