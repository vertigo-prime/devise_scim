# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Scim::Error do
  describe "#to_h" do
    it "includes the Error schema" do
      h = described_class.new(status: 400, detail: "bad").to_h
      expect(h["schemas"]).to include(DeviseScim::Scim::ERROR_SCHEMA)
    end

    it "casts status to string" do
      h = described_class.new(status: 404, detail: "not found").to_h
      expect(h["status"]).to eq("404")
    end

    it "includes detail" do
      h = described_class.new(status: 400, detail: "bad input").to_h
      expect(h["detail"]).to eq("bad input")
    end

    it "includes scimType when present" do
      h = described_class.new(status: 409, detail: "dup", scim_type: "uniqueness").to_h
      expect(h["scimType"]).to eq("uniqueness")
    end

    it "omits scimType when absent" do
      h = described_class.new(status: 404, detail: "not found").to_h
      expect(h).not_to have_key("scimType")
    end
  end

  describe "factory methods" do
    it ".unauthorized returns 401" do
      err = described_class.unauthorized
      expect(err.status).to eq(401)
      expect(err.detail).to eq("Unauthorized")
    end

    it ".unauthorized accepts custom detail" do
      expect(described_class.unauthorized("Custom").detail).to eq("Custom")
    end

    it ".not_found returns 404" do
      expect(described_class.not_found.status).to eq(404)
    end

    it ".conflict returns 409 with uniqueness scimType" do
      err = described_class.conflict
      expect(err.status).to eq(409)
      expect(err.scim_type).to eq("uniqueness")
    end

    it ".bad_request returns 400 with invalidValue scimType" do
      err = described_class.bad_request("Missing field")
      expect(err.status).to eq(400)
      expect(err.scim_type).to eq("invalidValue")
    end

    it ".bad_request accepts custom scim_type" do
      err = described_class.bad_request("Bad filter", scim_type: "invalidFilter")
      expect(err.scim_type).to eq("invalidFilter")
    end

    it ".unprocessable returns 422" do
      expect(described_class.unprocessable("detail").status).to eq(422)
    end

    it ".server_error returns 500" do
      expect(described_class.server_error.status).to eq(500)
    end
  end

  describe "#to_json" do
    it "produces valid JSON" do
      parsed = JSON.parse(described_class.not_found.to_json)
      expect(parsed["status"]).to eq("404")
    end
  end
end
