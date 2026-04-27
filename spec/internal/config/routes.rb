# frozen_string_literal: true

Rails.application.routes.draw do
  scim_for :users

  # Used by routing spec to verify Groups-enabled and OAuth-enabled conditional paths.
  DeviseScim.configure { |c| c.enable_groups = true }
  scim_for :users, at: "/scim_groups"
  DeviseScim.reset_configuration!

  DeviseScim.configure { |c| c.auth_method = :oauth }
  scim_for :users, at: "/scim_oauth"
  DeviseScim.reset_configuration!
end
