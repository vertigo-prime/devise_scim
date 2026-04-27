# frozen_string_literal: true

module DeviseScim
  class ScimTenantUser < ActiveRecord::Base
    self.table_name = "scim_tenant_users"

    # Default associations use built-in DeviseScim::ScimTenant and the host app's
    # User model. When config.tenant_model is customized, host apps override these
    # associations (and the FK) in their own initializer.
    belongs_to :scim_tenant,
               class_name: "DeviseScim::ScimTenant",
               foreign_key: :scim_tenant_id
    belongs_to :user, foreign_key: :user_id
  end
end
