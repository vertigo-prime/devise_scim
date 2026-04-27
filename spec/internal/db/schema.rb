# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :scim_tenants, force: true do |t|
    t.string  :name
    t.string  :auth_method, null: false, default: "token"
    t.string  :token_digest
    t.boolean :active, null: false, default: true
    t.integer :doorkeeper_application_id
    t.timestamps
  end
end
