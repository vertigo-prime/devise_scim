# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Scim::User do
  let(:full_hash) do
    {
      "id" => "abc-123",
      "externalId" => "ext-456",
      "userName" => "bjensen@example.com",
      "displayName" => "Barbara Jensen",
      "active" => true,
      "locale" => "en-US",
      "timezone" => "America/New_York",
      "title" => "Dr.",
      "name" => {
        "formatted" => "Barbara Jensen",
        "givenName" => "Barbara",
        "familyName" => "Jensen",
        "middleName" => "Jane",
        "honorificPrefix" => "Dr.",
        "honorificSuffix" => "Jr."
      },
      "emails" => [
        { "value" => "bjensen@example.com", "type" => "work", "primary" => true },
        { "value" => "bj@home.example.com", "type" => "home" }
      ],
      "phoneNumbers" => [
        { "value" => "+1-555-555-5555", "type" => "work", "primary" => true }
      ]
    }
  end

  describe ".from_h" do
    subject(:user) { described_class.from_h(full_hash) }

    it { expect(user.id).to eq("abc-123") }
    it { expect(user.external_id).to eq("ext-456") }
    it { expect(user.user_name).to eq("bjensen@example.com") }
    it { expect(user.display_name).to eq("Barbara Jensen") }
    it { expect(user.active).to be(true) }
    it { expect(user.locale).to eq("en-US") }
    it { expect(user.timezone).to eq("America/New_York") }
    it { expect(user.title).to eq("Dr.") }

    it "parses name sub-attributes" do
      expect(user.name.given_name).to eq("Barbara")
      expect(user.name.family_name).to eq("Jensen")
      expect(user.name.middle_name).to eq("Jane")
      expect(user.name.honorific_prefix).to eq("Dr.")
      expect(user.name.honorific_suffix).to eq("Jr.")
    end

    it "parses emails array" do
      expect(user.emails.size).to eq(2)
      primary = user.emails.first
      expect(primary.value).to eq("bjensen@example.com")
      expect(primary.type).to eq("work")
      expect(primary.primary).to be(true)
    end

    it "parses phoneNumbers array" do
      expect(user.phone_numbers.size).to eq(1)
      expect(user.phone_numbers.first.value).to eq("+1-555-555-5555")
    end

    it "defaults active to true when key absent" do
      user = described_class.from_h("userName" => "x@y.com")
      expect(user.active).to be(true)
    end

    it "preserves active: false" do
      user = described_class.from_h("userName" => "x@y.com", "active" => false)
      expect(user.active).to be(false)
    end

    it "tolerates missing name" do
      user = described_class.from_h("userName" => "x@y.com")
      expect(user.name).to be_nil
    end

    it "sets emails to empty array when absent" do
      user = described_class.from_h("userName" => "x@y.com")
      expect(user.emails).to eq([])
    end
  end

  describe "#to_h" do
    subject(:h) { described_class.from_h(full_hash).to_h }

    it "includes the User schema" do
      expect(h["schemas"]).to include(DeviseScim::Scim::USER_SCHEMA)
    end

    it "serializes scalar fields" do
      expect(h["id"]).to eq("abc-123")
      expect(h["externalId"]).to eq("ext-456")
      expect(h["userName"]).to eq("bjensen@example.com")
      expect(h["active"]).to be(true)
    end

    it "serializes name" do
      expect(h["name"]["givenName"]).to eq("Barbara")
      expect(h["name"]["familyName"]).to eq("Jensen")
    end

    it "serializes emails" do
      expect(h["emails"].first).to include("value" => "bjensen@example.com", "primary" => true)
    end

    it "serializes phoneNumbers" do
      expect(h["phoneNumbers"].first).to include("value" => "+1-555-555-5555")
    end

    it "omits nil scalar fields" do
      user = described_class.from_h("userName" => "x@y.com")
      h = user.to_h
      expect(h).not_to have_key("externalId")
      expect(h).not_to have_key("displayName")
    end

    it "omits name when not set" do
      user = described_class.from_h("userName" => "x@y.com")
      expect(user.to_h).not_to have_key("name")
    end

    it "omits emails when empty" do
      user = described_class.from_h("userName" => "x@y.com")
      expect(user.to_h).not_to have_key("emails")
    end
  end

  describe "#primary_email" do
    it "returns the primary email value" do
      user = described_class.from_h(full_hash)
      expect(user.primary_email).to eq("bjensen@example.com")
    end

    it "falls back to userName when no emails" do
      user = described_class.from_h("userName" => "fallback@example.com")
      expect(user.primary_email).to eq("fallback@example.com")
    end
  end

  describe "#to_json" do
    it "produces valid JSON" do
      user = described_class.from_h(full_hash)
      parsed = JSON.parse(user.to_json)
      expect(parsed["userName"]).to eq("bjensen@example.com")
    end
  end
end
