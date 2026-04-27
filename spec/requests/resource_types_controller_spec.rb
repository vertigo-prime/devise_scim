# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DeviseScim ResourceTypes", type: :request do
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

  describe "GET /scim/v2/ResourceTypes" do
    it "returns User resource type" do
      get "/scim/v2/ResourceTypes", headers: headers
      expect(response).to have_http_status(:ok)
      parsed = JSON.parse(response.body)
      names = parsed["Resources"].map { |r| r["name"] }
      expect(names).to include("User")
      expect(names).not_to include("Group")
    end

    context "groups enabled" do
      before { DeviseScim.configure { |c| c.enable_groups = true } }

      it "includes Group resource type" do
        get "/scim_groups/ResourceTypes", headers: headers
        parsed = JSON.parse(response.body)
        names = parsed["Resources"].map { |r| r["name"] }
        expect(names).to include("User", "Group")
      end
    end
  end
end
