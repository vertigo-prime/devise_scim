# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string :email
    t.timestamps
  end

  create_table :scim_tenants, force: true do |t|
    t.string  :name
    t.string  :auth_method, null: false, default: "token"
    t.string  :token_digest
    t.boolean :active, null: false, default: true
    t.integer :doorkeeper_application_id
    t.timestamps
  end

  create_table :scim_tenant_users, force: true do |t|
    t.bigint  :scim_tenant_id, null: false
    t.bigint  :user_id,        null: false
    t.string  :scim_uid
    t.datetime :provisioned_at
    t.datetime :scim_claimed_at
    t.boolean  :active, null: false, default: true
    t.text     :scim_raw
    t.timestamps
  end

  add_index :scim_tenant_users, %i[scim_tenant_id user_id],  unique: true
  add_index :scim_tenant_users, %i[scim_tenant_id scim_uid], unique: true,
                                                             where: "scim_uid IS NOT NULL"

  create_table :scim_groups, force: true do |t|
    t.string  :display_name
    t.string  :scim_group_uid
    t.integer :tenant_id
    t.timestamps
  end
end
