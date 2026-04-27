# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Scim::ListResponse do
  let(:user1) { DeviseScim::Scim::User.from_h("id" => "1", "userName" => "a@b.com") }
  let(:user2) { DeviseScim::Scim::User.from_h("id" => "2", "userName" => "c@d.com") }

  describe "#to_h" do
    it "includes the ListResponse schema" do
      h = described_class.new(resources: []).to_h
      expect(h["schemas"]).to include(DeviseScim::Scim::LIST_RESPONSE_SCHEMA)
    end

    it "sets totalResults from resources size by default" do
      h = described_class.new(resources: [user1, user2]).to_h
      expect(h["totalResults"]).to eq(2)
    end

    it "uses explicit total_results when provided" do
      h = described_class.new(resources: [user1], total_results: 50).to_h
      expect(h["totalResults"]).to eq(50)
    end

    it "defaults startIndex to 1" do
      h = described_class.new(resources: []).to_h
      expect(h["startIndex"]).to eq(1)
    end

    it "defaults itemsPerPage to 100" do
      h = described_class.new(resources: []).to_h
      expect(h["itemsPerPage"]).to eq(100)
    end

    it "accepts custom startIndex and itemsPerPage" do
      h = described_class.new(resources: [], start_index: 11, items_per_page: 10).to_h
      expect(h["startIndex"]).to eq(11)
      expect(h["itemsPerPage"]).to eq(10)
    end

    it "calls to_h on each resource" do
      h = described_class.new(resources: [user1, user2]).to_h
      expect(h["Resources"].map { |r| r["id"] }).to eq(%w[1 2])
    end

    it "passes raw hashes through when resource has no to_h" do
      raw = { "id" => "raw" }
      h = described_class.new(resources: [raw]).to_h
      expect(h["Resources"].first).to eq(raw)
    end
  end

  describe "#to_json" do
    it "produces valid JSON" do
      parsed = JSON.parse(described_class.new(resources: [user1]).to_json)
      expect(parsed["totalResults"]).to eq(1)
      expect(parsed["Resources"].first["userName"]).to eq("a@b.com")
    end
  end
end
