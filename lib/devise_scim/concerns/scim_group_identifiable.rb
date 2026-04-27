# frozen_string_literal: true

module DeviseScim
  module Concerns
    module ScimGroupIdentifiable
      extend ActiveSupport::Concern

      class_methods do
        def find_by_scim_uid(uid, tenant: nil)
          scope = where(scim_group_uid: uid)
          scope = scope.where(tenant_id: tenant.id) if tenant && column_names.include?("tenant_id")
          scope.first
        end

        def authenticate_scim_group(scim_group, tenant: nil)
          find_by_scim_uid(scim_group.external_id || scim_group.id, tenant: tenant)
        end
      end
    end
  end
end
