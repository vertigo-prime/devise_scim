# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::ScimTenant do
  def create_tenant(attrs = {})
    described_class.create!({ name: "Acme", auth_method: "token", active: true }.merge(attrs))
  end

  describe "concern inclusion" do
    it "responds to authenticate_token" do
      expect(described_class).to respond_to(:authenticate_token)
    end

    it "responds to scim_tenant_label_column" do
      expect(described_class).to respond_to(:scim_tenant_label_column)
    end

    it "responds to rotate_token!" do
      expect(create_tenant).to respond_to(:rotate_token!)
    end

    it "responds to scim_active?" do
      expect(create_tenant).to respond_to(:scim_active?)
    end
  end

  describe ".authenticate_token" do
    let(:raw) { SecureRandom.hex(32) }
    let!(:tenant) do
      t = create_tenant
      t.update!(token_digest: BCrypt::Password.create(raw))
      t
    end

    it "returns matching record" do
      expect(described_class.authenticate_token(raw)).to eq(tenant)
    end

    it "returns nil on mismatch" do
      expect(described_class.authenticate_token("wrong")).to be_nil
    end

    it "ignores inactive records" do
      tenant.update!(active: false)
      expect(described_class.authenticate_token(raw)).to be_nil
    end

    it "ignores oauth records" do
      tenant.update!(auth_method: "oauth")
      expect(described_class.authenticate_token(raw)).to be_nil
    end
  end

  describe "#rotate_token!" do
    let(:tenant) { create_tenant }

    it "stores bcrypt digest" do
      plaintext = tenant.rotate_token!
      tenant.reload
      expect(BCrypt::Password.new(tenant.token_digest).is_password?(plaintext)).to be true
    end
  end

  describe "#scim_active?" do
    it "delegates to active column" do
      expect(create_tenant(active: true).scim_active?).to be true
      expect(create_tenant(active: false).scim_active?).to be false
    end
  end

  describe "validations" do
    it "is invalid with bad auth_method" do
      record = described_class.new(name: "Acme", auth_method: "bad")
      expect(record.valid?).to be false
    end

    it "is invalid without name" do
      record = described_class.new(auth_method: "token", name: nil)
      expect(record.valid?).to be false
    end
  end

  describe "associations" do
    let(:tenant) { create_tenant }

    it "has many scim_tenant_users" do
      expect(tenant).to respond_to(:scim_tenant_users)
    end

    it "scim_tenant_users returns empty collection by default" do
      expect(tenant.scim_tenant_users.to_a).to eq([])
    end
  end
end
