# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::Concerns::ScimGroupIdentifiable do
  let!(:group) { ScimGroup.create!(display_name: "Admins", scim_group_uid: "ext-grp-1") }

  describe ".find_by_scim_uid" do
    it "returns the matching record" do
      expect(ScimGroup.find_by_scim_uid("ext-grp-1")).to eq(group)
    end

    it "returns nil when no match" do
      expect(ScimGroup.find_by_scim_uid("nope")).to be_nil
    end

    it "ignores nil tenant parameter" do
      expect(ScimGroup.find_by_scim_uid("ext-grp-1", tenant: nil)).to eq(group)
    end

    context "when tenant_id column exists and tenant is provided" do
      let(:tenant) { DeviseScim::ScimTenant.create!(name: "Acme", auth_method: "token", active: true) }
      let!(:group_with_tenant) do
        ScimGroup.create!(display_name: "Devs", scim_group_uid: "ext-grp-2", tenant_id: tenant.id)
      end

      it "scopes to the tenant" do
        expect(ScimGroup.find_by_scim_uid("ext-grp-2", tenant: tenant)).to eq(group_with_tenant)
      end

      it "returns nil for wrong tenant" do
        other = DeviseScim::ScimTenant.create!(name: "Other", auth_method: "token", active: true)
        expect(ScimGroup.find_by_scim_uid("ext-grp-2", tenant: other)).to be_nil
      end
    end
  end

  describe ".authenticate_scim_group" do
    let(:scim_group) do
      DeviseScim::Scim::Group.from_h("externalId" => "ext-grp-1", "displayName" => "Admins")
    end

    it "finds by externalId" do
      expect(ScimGroup.authenticate_scim_group(scim_group)).to eq(group)
    end

    context "when externalId is absent" do
      let(:scim_group_by_id) do
        DeviseScim::Scim::Group.from_h("id" => "ext-grp-1", "displayName" => "Admins")
      end

      it "falls back to id" do
        expect(ScimGroup.authenticate_scim_group(scim_group_by_id)).to eq(group)
      end
    end
  end
end
