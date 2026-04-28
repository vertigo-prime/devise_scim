# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DeviseScim Groups", type: :request do
  let(:token) { "test-scim-token" }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  before do
    DeviseScim.configure do |c|
      c.tenancy     = :single
      c.auth_method = :token
      c.token       = token
      c.enable_groups = true
    end
  end

  after { DeviseScim.reset_configuration! }

  def scim_json(body)
    JSON.parse(body)
  end

  describe "GET /scim_groups/Groups" do
    it "returns empty ListResponse" do
      get "/scim_groups/Groups", headers: headers
      expect(response).to have_http_status(:ok)
      parsed = scim_json(response.body)
      expect(parsed["totalResults"]).to eq(0)
      expect(parsed["Resources"]).to eq([])
    end
  end

  describe "POST /scim_groups/Groups" do
    let(:payload) do
      {
        "schemas" => [DeviseScim::Scim::GROUP_SCHEMA],
        "displayName" => "Admins"
      }
    end

    it "returns 500 when group_to_scim not implemented (default adapter)" do
      post "/scim_groups/Groups", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "GET /scim_groups/Groups/:id" do
    it "returns 500 when group_to_scim not implemented" do
      get "/scim_groups/Groups/grp-1", headers: headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "PUT /scim_groups/Groups/:id" do
    let(:payload) { { "schemas" => [DeviseScim::Scim::GROUP_SCHEMA], "displayName" => "Admins" } }

    it "returns 500 when group_to_scim not implemented" do
      put "/scim_groups/Groups/grp-1", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "PATCH /scim_groups/Groups/:id" do
    let(:payload) { { "schemas" => [DeviseScim::Scim::GROUP_SCHEMA], "displayName" => "Admins" } }

    it "returns 500 when group_to_scim not implemented" do
      patch "/scim_groups/Groups/grp-1", params: payload.to_json, headers: headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end

  describe "DELETE /scim_groups/Groups/:id" do
    it "calls handle_group_destroy and returns 204" do
      adapter = instance_double(DeviseScim::ScimAdapter, handle_group_destroy: nil)
      allow(DeviseScim::ScimAdapter).to receive(:new).and_return(adapter)

      delete "/scim_groups/Groups/grp-1", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(adapter).to have_received(:handle_group_destroy)
    end
  end

  describe "POST /scim_groups/Groups with invalid JSON" do
    it "returns 500 (parsed_body falls back to empty hash)" do
      post "/scim_groups/Groups", params: "not-json", headers: headers
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
