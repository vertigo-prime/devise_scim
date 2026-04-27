# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DeviseScim Schemas", type: :request do
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

  describe "GET /scim/v2/Schemas" do
    context "groups disabled" do
      it "returns User schema only" do
        get "/scim/v2/Schemas", headers: headers
        parsed = JSON.parse(response.body)
        expect(parsed["totalResults"]).to eq(1)
        ids = parsed["Resources"].map { |r| r["id"] }
        expect(ids).to include(DeviseScim::Scim::USER_SCHEMA)
        expect(ids).not_to include(DeviseScim::Scim::GROUP_SCHEMA)
      end
    end

    context "groups enabled" do
      before { DeviseScim.configure { |c| c.enable_groups = true } }

      it "returns User and Group schemas" do
        get "/scim_groups/Schemas", headers: headers
        parsed = JSON.parse(response.body)
        ids = parsed["Resources"].map { |r| r["id"] }
        expect(ids).to include(DeviseScim::Scim::USER_SCHEMA, DeviseScim::Scim::GROUP_SCHEMA)
      end
    end
  end
end
