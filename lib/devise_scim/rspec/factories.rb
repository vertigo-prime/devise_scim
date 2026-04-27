# frozen_string_literal: true

return unless defined?(FactoryBot)

FactoryBot.define do
  factory :scim_tenant, class: "DeviseScim::ScimTenant" do
    sequence(:name) { |n| "Test Tenant #{n}" }
    auth_method { "token" }
    active { true }
  end

  factory :scim_tenant_user, class: "DeviseScim::ScimTenantUser" do
    association :scim_tenant
    active { true }
    provisioned_at { Time.current }
  end
end
