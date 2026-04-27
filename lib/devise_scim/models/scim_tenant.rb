# frozen_string_literal: true

module DeviseScim
  class ScimTenant < ActiveRecord::Base
    self.table_name = "scim_tenants"

    include DeviseScim::Concerns::ScimTenant

    has_many :scim_tenant_users, class_name: "DeviseScim::ScimTenantUser",
                                 foreign_key: :scim_tenant_id, dependent: :destroy
    belongs_to :doorkeeper_application,
               class_name: "Doorkeeper::Application", optional: true
  end
end
