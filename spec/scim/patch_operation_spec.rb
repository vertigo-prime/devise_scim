# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Scim::PatchOperation do
  describe ".parse" do
    it "accepts 'replace' op" do
      op = described_class.parse("op" => "replace", "path" => "active", "value" => false)
      expect(op.op).to eq("replace")
    end

    it "accepts 'add' op" do
      expect(described_class.parse("op" => "add", "value" => { "displayName" => "X" }).op).to eq("add")
    end

    it "accepts 'remove' op" do
      expect(described_class.parse("op" => "remove", "path" => "emails").op).to eq("remove")
    end

    it "normalizes op to downcase" do
      op = described_class.parse("op" => "Replace", "path" => "active", "value" => true)
      expect(op.op).to eq("replace")
    end

    it "raises ArgumentError for invalid op" do
      expect { described_class.parse("op" => "upsert", "path" => "x") }
        .to raise_error(ArgumentError, /upsert/)
    end

    it "raises ArgumentError for nil op" do
      expect { described_class.parse({}) }.to raise_error(ArgumentError)
    end

    it "stores value" do
      op = described_class.parse("op" => "replace", "path" => "active", "value" => false)
      expect(op.value).to be(false)
    end

    it "stores raw_path" do
      op = described_class.parse("op" => "replace", "path" => "name.givenName", "value" => "Bob")
      expect(op.raw_path).to eq("name.givenName")
    end
  end

  describe ".parse_request" do
    let(:body) do
      {
        "Operations" => [
          { "op" => "replace", "path" => "active", "value" => false },
          { "op" => "add", "value" => { "displayName" => "New" } }
        ]
      }
    end

    it "returns an array of PatchOperations" do
      ops = described_class.parse_request(body)
      expect(ops.size).to eq(2)
      expect(ops.map(&:op)).to eq(%w[replace add])
    end

    it "falls back to 'operations' key" do
      ops = described_class.parse_request("operations" => [{ "op" => "remove", "path" => "emails" }])
      expect(ops.size).to eq(1)
    end

    it "returns empty array when key absent" do
      expect(described_class.parse_request({})).to eq([])
    end
  end

  describe "path parsing" do
    def op_for(path)
      described_class.parse("op" => "replace", "path" => path, "value" => nil)
    end

    it "simple attribute" do
      op = op_for("active")
      expect(op.attribute).to eq("active")
      expect(op.sub_attribute).to be_nil
      expect(op.filter).to be_nil
    end

    it "dotted sub-attribute" do
      op = op_for("name.givenName")
      expect(op.attribute).to eq("name")
      expect(op.sub_attribute).to eq("givenName")
      expect(op.filter).to be_nil
    end

    it "filter expression only" do
      op = op_for('emails[type eq "work"]')
      expect(op.attribute).to eq("emails")
      expect(op.filter).to eq('type eq "work"')
      expect(op.sub_attribute).to be_nil
    end

    it "filter expression with sub-attribute" do
      op = op_for('emails[type eq "work"].value')
      expect(op.attribute).to eq("emails")
      expect(op.filter).to eq('type eq "work"')
      expect(op.sub_attribute).to eq("value")
    end

    it "nil path leaves all path fields nil" do
      op = described_class.parse("op" => "add", "value" => { "displayName" => "X" })
      expect(op.attribute).to be_nil
      expect(op.filter).to be_nil
      expect(op.sub_attribute).to be_nil
    end
  end
end
