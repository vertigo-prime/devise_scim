## [Unreleased]

## [0.1.1] - 2026-04-27

## [0.1.0] - 2026-04-27

### Added

- SCIM 2.0 server engine (RFC 7643 / 7644) mountable into any Rails + Devise application
- `UsersController` — full CRUD with PATCH op application, re-provisioning matrix, and configurable deprovision behavior for manual users
- `GroupsController` — protocol layer delegating to `ScimAdapter`; gracefully handles unimplemented group operations
- `ServiceProviderController`, `SchemasController`, `ResourceTypesController` — static RFC 7643 discovery responses
- `ScimAdapter` base class — pluggable attribute mapping for create/update, `to_scim`, lifecycle callbacks (`after_provision`, `after_deprovision`), and no-op group callbacks
- Single-tenant and multi-tenant deployment modes (`config.tenancy`)
- Bearer token authentication with bcrypt-safe digest comparison (`config.auth_method = :token`)
- OAuth 2.0 client credentials authentication via optional Doorkeeper integration (`config.auth_method = :oauth`)
- `DeviseScim::Concerns::ScimTenant` — brings the full tenant interface to host-app models (`authenticate_token`, `rotate_token!`, `scim_active?`)
- `DeviseScim::Concerns::ScimGroupIdentifiable` — optional concern for group/role models to standardize `scim_group_uid` storage and lookup
- SCIM filter parser — tokenizer and recursive-descent AST builder supporting `eq`, `ne`, `co`, `sw`, `ew`, `pr`, `gt`, `ge`, `lt`, `le`, `and`, `or`, `not`
- `ArelVisitor` — pure Arel condition builder (no string interpolation) that maps SCIM attribute names to AR columns
- `DeviseScim::Middleware::Authenticator` — Warden-aware middleware that resolves the tenant from the inbound credential
- `scim_for` routing helper with `groups:` and `oauth:` opt-in flags
- Install generator (`rails g devise_scim:install`) supporting single-tenant, multi-tenant, and custom tenant-model modes; Doorkeeper preflight check for OAuth/multi-tenant
- Adapter generator (`rails g devise_scim:adapter`)
- RSpec test harness (`require "devise_scim/rspec"`) — `ScimHelpers`, `ScimAssertions`, shared examples for Users, Groups, and discovery endpoints; FactoryBot factories
- Minitest test harness (`require "devise_scim/minitest"`) with equivalent helpers and assertions
- Comprehensive documentation: `README.md`, `docs/custom_adapter.md`, `docs/multi_tenant.md`, `docs/idp_setup.md`, `docs/testing.md`, `docs/contributing.md`
