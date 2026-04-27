# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.shared_examples "a SCIM Groups endpoint" do |_options = {}|
  include DeviseScim::RSpec::ScimHelpers

  let(:_scim_test_token) { "scim-test-token-#{SecureRandom.hex(8)}" }
  let(:_scim_headers)    { scim_auth_headers(_scim_test_token) }

  before do
    DeviseScim.configure do |c|
      c.tenancy       = :single
      c.auth_method   = :token
      c.token         = _scim_test_token
      c.enable_groups = true
    end
  end

  after { DeviseScim.reset_configuration! }

  # ── GET /Groups ──────────────────────────────────────────────────────────────

  describe "GET /Groups" do
    it "returns 200 with an empty ListResponse" do
      get "#{scim_prefix}/Groups", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      expect(body["schemas"]).to include(DeviseScim::Scim::LIST_RESPONSE_SCHEMA)
      expect(body["Resources"]).to eq([])
    end

    it "sets Content-Type to application/scim+json" do
      get "#{scim_prefix}/Groups", headers: _scim_headers
      expect(response.content_type).to include("application/scim+json")
    end
  end

  # ── POST /Groups ─────────────────────────────────────────────────────────────

  describe "POST /Groups" do
    let(:_group_payload) do
      { "schemas" => [DeviseScim::Scim::GROUP_SCHEMA], "displayName" => "Test Group" }
    end

    context "when the adapter implements group_to_scim" do
      let(:_group_scim_obj) do
        grp = DeviseScim::Scim::Group.new
        grp.id = "test-grp-1"
        grp.display_name = "Test Group"
        grp
      end
      let(:_adapter_spy) do
        instance_double(DeviseScim::ScimAdapter,
                        handle_group_create: nil,
                        group_to_scim: _group_scim_obj)
      end

      before { allow(DeviseScim::ScimAdapter).to receive(:new).and_return(_adapter_spy) }

      it "calls handle_group_create on the adapter" do
        post "#{scim_prefix}/Groups", params: _group_payload.to_json, headers: _scim_headers
        expect(_adapter_spy).to have_received(:handle_group_create)
      end

      it "returns 201 with the group representation" do
        post "#{scim_prefix}/Groups", params: _group_payload.to_json, headers: _scim_headers
        expect(response).to have_http_status(:created)
        body = scim_json(response.body)
        expect(body["displayName"]).to eq("Test Group")
      end
    end

    context "when the adapter does not implement group_to_scim (default)" do
      it "returns 500" do
        post "#{scim_prefix}/Groups", params: _group_payload.to_json, headers: _scim_headers
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  # ── GET /Groups/:id ──────────────────────────────────────────────────────────

  describe "GET /Groups/:id" do
    let(:_group_scim_obj) do
      grp = DeviseScim::Scim::Group.new
      grp.id = "grp-42"
      grp.display_name = "My Group"
      grp
    end
    let(:_adapter_spy) do
      instance_double(DeviseScim::ScimAdapter, group_to_scim: _group_scim_obj)
    end

    before { allow(DeviseScim::ScimAdapter).to receive(:new).and_return(_adapter_spy) }

    it "returns 200 with the group serialised by the adapter" do
      get "#{scim_prefix}/Groups/grp-42", headers: _scim_headers
      expect(response).to have_http_status(:ok)
      body = scim_json(response.body)
      expect(body["id"]).to eq("grp-42")
    end
  end

  # ── PATCH /Groups/:id ────────────────────────────────────────────────────────

  describe "PATCH /Groups/:id" do
    let(:_group_scim_obj) do
      grp = DeviseScim::Scim::Group.new
      grp.id = "grp-42"
      grp.display_name = "Updated Group"
      grp
    end
    let(:_adapter_spy) do
      instance_double(DeviseScim::ScimAdapter,
                      handle_group_update: nil,
                      group_to_scim: _group_scim_obj)
    end

    before { allow(DeviseScim::ScimAdapter).to receive(:new).and_return(_adapter_spy) }

    it "calls handle_group_update on the adapter and returns 200" do
      payload = {
        "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
        "Operations" => [{ "op" => "replace", "value" => { "displayName" => "Updated Group" } }]
      }
      patch "#{scim_prefix}/Groups/grp-42", params: payload.to_json, headers: _scim_headers
      expect(response).to have_http_status(:ok)
      expect(_adapter_spy).to have_received(:handle_group_update)
    end
  end

  # ── DELETE /Groups/:id ───────────────────────────────────────────────────────

  describe "DELETE /Groups/:id" do
    let(:_adapter_spy) do
      instance_double(DeviseScim::ScimAdapter, handle_group_destroy: nil)
    end

    before { allow(DeviseScim::ScimAdapter).to receive(:new).and_return(_adapter_spy) }

    it "calls handle_group_destroy on the adapter and returns 204" do
      delete "#{scim_prefix}/Groups/grp-42", headers: _scim_headers
      expect(response).to have_http_status(:no_content)
      expect(_adapter_spy).to have_received(:handle_group_destroy)
    end
  end
end
# rubocop:enable Metrics/BlockLength
