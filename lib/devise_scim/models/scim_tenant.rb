# frozen_string_literal: true

module DeviseScim
  class ScimTenant < ActiveRecord::Base
    self.table_name = "scim_tenants"

    include DeviseScim::Concerns::ScimTenant
  end
end
