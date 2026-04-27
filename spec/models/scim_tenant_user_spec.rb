# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::ScimTenantUser do
  let(:tenant) do
    DeviseScim::ScimTenant.create!(name: "Acme", auth_method: "token", active: true)
  end
  let(:user) { User.create!(email: "alice@example.com") }

  def create_tenant_user(attrs = {})
    described_class.create!({
      scim_tenant: tenant,
      user: user,
      active: true
    }.merge(attrs))
  end

  describe "associations" do
    it "belongs_to scim_tenant" do
      tu = create_tenant_user
      expect(tu.scim_tenant).to eq(tenant)
    end

    it "belongs_to user" do
      tu = create_tenant_user
      expect(tu.user).to eq(user)
    end

    it "is accessible from scim_tenant side" do
      create_tenant_user
      expect(tenant.scim_tenant_users.count).to eq(1)
    end
  end

  describe "columns" do
    it "stores scim_uid" do
      tu = create_tenant_user(scim_uid: "ext-123")
      expect(tu.reload.scim_uid).to eq("ext-123")
    end

    it "defaults active to true" do
      tu = create_tenant_user
      expect(tu.active).to be true
    end
  end
end
