# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Scim::Group do
  let(:full_hash) do
    {
      "id" => "g-001",
      "externalId" => "ext-g-001",
      "displayName" => "Admins",
      "members" => [
        { "value" => "u-1", "display" => "Alice", "$ref" => "/Users/u-1" },
        { "value" => "u-2", "display" => "Bob" }
      ]
    }
  end

  describe ".from_h" do
    subject(:group) { described_class.from_h(full_hash) }

    it { expect(group.id).to eq("g-001") }
    it { expect(group.external_id).to eq("ext-g-001") }
    it { expect(group.display_name).to eq("Admins") }

    it "parses members" do
      expect(group.members.size).to eq(2)
      alice = group.members.first
      expect(alice.value).to eq("u-1")
      expect(alice.display).to eq("Alice")
      expect(alice.ref).to eq("/Users/u-1")
    end

    it "sets members to empty array when absent" do
      group = described_class.from_h("displayName" => "Empty")
      expect(group.members).to eq([])
    end
  end

  describe "#to_h" do
    subject(:h) { described_class.from_h(full_hash).to_h }

    it "includes the Group schema" do
      expect(h["schemas"]).to include(DeviseScim::Scim::GROUP_SCHEMA)
    end

    it { expect(h["id"]).to eq("g-001") }
    it { expect(h["displayName"]).to eq("Admins") }

    it "serializes members" do
      expect(h["members"].first).to include("value" => "u-1", "display" => "Alice", "$ref" => "/Users/u-1")
    end

    it "omits nil member fields" do
      expect(h["members"].last).not_to have_key("$ref")
    end

    it "omits nil scalar fields" do
      group = described_class.from_h("displayName" => "X")
      expect(group.to_h).not_to have_key("externalId")
    end

    it "includes empty members array" do
      group = described_class.from_h("displayName" => "Empty")
      expect(group.to_h["members"]).to eq([])
    end
  end

  describe "#to_h with meta" do
    let(:created_time)  { Time.utc(2026, 1, 2, 3, 4, 5) }
    let(:modified_time) { Time.utc(2026, 5, 6, 7, 8, 9) }

    it "serializes meta with iso8601 conversion for time-like values" do
      group = described_class.from_h(full_hash)
      group.meta = DeviseScim::Scim::Meta.new(
        resource_type: "Group",
        created: created_time,
        last_modified: modified_time
      )
      meta = group.to_h["meta"]
      expect(meta["resourceType"]).to eq("Group")
      expect(meta["created"]).to eq(created_time.iso8601)
      expect(meta["lastModified"]).to eq(modified_time.iso8601)
    end

    it "passes raw values through when they do not respond to iso8601" do
      group = described_class.from_h(full_hash)
      group.meta = DeviseScim::Scim::Meta.new(
        resource_type: nil,
        created: "2026-01-02T03:04:05Z",
        last_modified: "2026-05-06T07:08:09Z"
      )
      meta = group.to_h["meta"]
      expect(meta["resourceType"]).to eq("Group")
      expect(meta["created"]).to eq("2026-01-02T03:04:05Z")
      expect(meta["lastModified"]).to eq("2026-05-06T07:08:09Z")
    end
  end

  describe "#to_json" do
    it "produces valid JSON" do
      parsed = JSON.parse(described_class.from_h(full_hash).to_json)
      expect(parsed["displayName"]).to eq("Admins")
    end
  end
end
