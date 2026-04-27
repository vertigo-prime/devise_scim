# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Concerns::ScimTenant do
  # Anonymous AR class — isolates concern from ScimTenant model.
  # Requires explicit model_name so Rails 7+ can generate i18n error messages.
  let(:model_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = "scim_tenants"
      def self.model_name
        ActiveModel::Name.new(self, nil, "TenantStub")
      end
      include DeviseScim::Concerns::ScimTenant
    end
  end

  def build_tenant(attrs = {})
    model_class.new({ name: "Acme", auth_method: "token", active: true }.merge(attrs))
  end

  def create_tenant(attrs = {})
    model_class.create!({ name: "Acme", auth_method: "token", active: true }.merge(attrs))
  end

  describe ".authenticate_token" do
    let(:raw) { SecureRandom.hex(32) }
    let!(:tenant) do
      t = create_tenant
      t.update!(token_digest: BCrypt::Password.create(raw))
      t
    end

    it "returns matching record" do
      expect(model_class.authenticate_token(raw)).to eq(tenant)
    end

    it "returns nil on mismatch" do
      expect(model_class.authenticate_token("wrong")).to be_nil
    end

    it "ignores inactive records" do
      tenant.update!(active: false)
      expect(model_class.authenticate_token(raw)).to be_nil
    end

    it "ignores oauth-auth records" do
      tenant.update!(auth_method: "oauth")
      expect(model_class.authenticate_token(raw)).to be_nil
    end
  end

  describe "#rotate_token!" do
    let(:tenant) { create_tenant }

    it "stores a bcrypt digest, not plaintext" do
      plaintext = tenant.rotate_token!
      tenant.reload
      expect(tenant.token_digest).not_to eq(plaintext)
      expect(tenant.token_digest).to start_with("$2a$")
    end

    it "returns the plaintext token (verifiable against the stored digest)" do
      plaintext = tenant.rotate_token!
      tenant.reload
      expect(BCrypt::Password.new(tenant.token_digest).is_password?(plaintext)).to be true
    end
  end

  describe "#scim_active?" do
    it "returns true when active column is true" do
      expect(build_tenant(active: true).scim_active?).to be true
    end

    it "returns false when active column is false" do
      expect(build_tenant(active: false).scim_active?).to be false
    end
  end

  describe "validations" do
    it "is invalid when auth_method is not in allowed list" do
      expect(build_tenant(auth_method: "magic").valid?).to be false
    end

    it "is invalid when label column (name) is blank" do
      expect(build_tenant(name: nil).valid?).to be false
    end
  end

  describe ".scim_tenant_label_column" do
    it "returns :name by default" do
      expect(model_class.scim_tenant_label_column).to eq(:name)
    end
  end
end
