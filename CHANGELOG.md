## [Unreleased]

## [0.1.17] - 2026-06-17

- Bump doorkeeper from 5.9.1 to 5.9.2
- Bump rubocop from 1.86.2 to 1.87.0
- Bump net-imap in the bundler group across 1 directory
- Bump codecov/codecov-action from 6.0.1 to 7.0.0
- Bump actions/checkout

## [0.1.16] - 2026-05-31

- Bump ruby/setup-ruby from 1.308.0 to 1.310.0
- Bump doorkeeper from 5.9.0 to 5.9.1
- Bump codecov/codecov-action from 6.0.0 to 6.0.1
- Bump rubocop from 1.86.1 to 1.86.2
- Bump ruby/setup-ruby from 1.306.0 to 1.308.0
- fix: improve error handling for unknown AST nodes and comparison operators
- chore: update CHANGELOG.md with recent dependency updates and CI changes
- chore: update dependencies in Gemfile.lock
- Bump devise from 5.0.3 to 5.0.4 in the bundler group across 1 directory
- Bump actions/checkout
- ci: add auto-approval for Dependabot PRs
- ci: skip Codecov upload on Dependabot PRs
- ci: pin dependabot actions, add cooldown and auto-merge
- Bump ruby/setup-ruby from 1.302.0 to 1.306.0
- chore: update CHANGELOG.md with recent dependency updates and CI changes
- chore: update dependencies in Gemfile.lock
- Bump devise from 5.0.3 to 5.0.4 in the bundler group across 1 directory
- Bump actions/checkout
- ci: add auto-approval for Dependabot PRs
- ci: skip Codecov upload on Dependabot PRs
- ci: pin dependabot actions, add cooldown and auto-merge

## [0.1.15] - 2026-05-02

- docs: update AGENTS.md with Minitest assertions and clarify auth strategies
- chore: create SECURITY.md for security policy and guidelines
- Update issue templates
- fix: correct link to contributing guidelines in README
- fix: correct link to contributing guidelines in README
- Remove test log and ignoring it

## [0.1.14] - 2026-04-28

- ci: populate CHANGELOG with commits on release

## [0.1.13] - 2026-04-28

## [0.1.12] - 2026-04-28

## [0.1.11] - 2026-04-28

## [0.1.10] - 2026-04-28

## [0.1.9] - 2026-04-28

## [0.1.8] - 2026-04-28

## [0.1.7] - 2026-04-28

## [0.1.6] - 2026-04-28

## [0.1.5] - 2026-04-28

## [0.1.4] - 2026-04-28

## [0.1.3] - 2026-04-28

## [0.1.2] - 2026-04-27

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
