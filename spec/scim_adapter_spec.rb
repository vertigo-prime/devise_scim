# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeviseScim::ScimAdapter do
  let(:user) { User.create!(email: "alice@example.com") }
  let(:scim_u) do
    DeviseScim::Scim::User.from_h(
      "userName" => "alice@example.com",
      "name" => { "givenName" => "Alice", "familyName" => "Smith" },
      "emails" => [{ "value" => "alice@example.com", "type" => "work", "primary" => true }]
    )
  end
  let(:scim_g) { DeviseScim::Scim::Group.from_h("displayName" => "Admins") }

  describe "#initialize" do
    it "assigns scim_user when passed a Scim::User" do
      adapter = described_class.new(user, scim_u)
      expect(adapter.scim_user).to be(scim_u)
      expect(adapter.scim_group).to be_nil
    end

    it "assigns scim_group when passed a Scim::Group" do
      adapter = described_class.new(user, scim_g)
      expect(adapter.scim_group).to be(scim_g)
      expect(adapter.scim_user).to be_nil
    end

    it "assigns tenant" do
      tenant  = DeviseScim::ScimTenant.create!(name: "Acme", auth_method: "token", active: true)
      adapter = described_class.new(user, scim_u, tenant: tenant)
      expect(adapter.tenant).to eq(tenant)
    end
  end

  describe "#attributes_for_create and #attributes_for_update" do
    subject(:adapter) { described_class.new(user, scim_u) }

    it "maps userName to email" do
      expect(adapter.attributes_for_create).to include(email: "alice@example.com")
    end

    it "omits first_name when column absent" do
      expect(adapter.attributes_for_create).not_to have_key(:first_name)
    end

    it "omits last_name when column absent" do
      expect(adapter.attributes_for_create).not_to have_key(:last_name)
    end

    it "attributes_for_update returns same mapping" do
      expect(adapter.attributes_for_update).to eq(adapter.attributes_for_create)
    end
  end

  describe "#to_scim" do
    subject(:scim) { described_class.new(user, scim_u).to_scim }

    it "returns a Scim::User" do
      expect(scim).to be_a(DeviseScim::Scim::User)
    end

    it "sets id from record" do
      expect(scim.id).to eq(user.id.to_s)
    end

    it "sets user_name from email" do
      expect(scim.user_name).to eq("alice@example.com")
    end

    it "sets active true when no scim_active column" do
      expect(scim.active).to be(true)
    end

    it "sets primary email" do
      email = scim.emails.first
      expect(email.value).to eq("alice@example.com")
      expect(email.primary).to be(true)
    end

    it "has no name when first_name/last_name columns absent" do
      expect(scim.name).to be_nil
    end

    it "sets meta resource_type to User" do
      expect(scim.meta.resource_type).to eq("User")
    end

    it "sets meta.created from record.created_at" do
      expect(scim.meta.created).to eq(user.created_at)
    end

    it "sets meta.last_modified from record.updated_at" do
      expect(scim.meta.last_modified).to eq(user.updated_at)
    end
  end

  describe "#group_to_scim" do
    it "raises NotImplementedError" do
      adapter = described_class.new(user, scim_g)
      expect { adapter.group_to_scim }.to raise_error(NotImplementedError)
    end
  end

  describe "lifecycle callbacks" do
    subject(:adapter) { described_class.new(user, scim_u) }

    it "after_provision is a no-op" do
      expect(adapter.after_provision).to be_nil
    end

    it "after_deprovision is a no-op" do
      expect(adapter.after_deprovision).to be_nil
    end
  end

  describe "group callbacks" do
    subject(:adapter) { described_class.new(user, scim_g) }

    it "handle_group_create is a no-op" do
      expect(adapter.handle_group_create).to be_nil
    end

    it "handle_group_update is a no-op" do
      expect(adapter.handle_group_update).to be_nil
    end

    it "handle_group_destroy is a no-op" do
      expect(adapter.handle_group_destroy).to be_nil
    end
  end
end
