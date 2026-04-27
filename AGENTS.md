# AGENTS.md

This is `devise_scim` — a SCIM 2.0 server engine for Rails + Devise applications.

## Key directory layout

| Path | Contents |
|------|----------|
| `lib/devise_scim/` | Gem code: configuration, auth strategies, filter system, SCIM structs, routing, adapter base class, Railtie/engine |
| `app/controllers/devise_scim/` | Controller layer: UsersController, GroupsController, ServiceProviderController, SchemasController, ResourceTypesController, ApplicationController |
| `lib/generators/` | `devise_scim:install` and `devise_scim:adapter` generators, plus all `.rb.tt` migration and initializer templates |
| `spec/` | RSpec suite — unit specs for every subsystem, request specs for all endpoints |
| `spec/internal/` | Combustion test app: `db/schema.rb`, `config/routes.rb`, minimal models, warden initializer |
| `lib/devise_scim/rspec/` | Host-app test harness: shared examples for Users/Groups/discovery endpoints, `ScimHelpers`, FactoryBot factories |

## Required checks before any commit

Run all three before opening a PR. A single failure is a blocker.

```sh
bundle exec rspec                              # 0 failures required
bundle exec rubocop                            # 0 offenses required (run --autocorrect for safe fixes first)
bundle exec brakeman --force --no-pager        # 0 security warnings required
```

## Configuration contract

All configuration lives in `DeviseScim::Configuration` (`lib/devise_scim/configuration.rb`). The generated initializer template is `lib/generators/devise_scim/templates/devise_scim.rb.tt`.

**Rule:** changing a default or adding a new attribute requires updating **both** files. The `.tt` template is what host apps receive — it must stay in sync with `configuration.rb`.

| Attribute | Valid values | Default |
|-----------|-------------|---------|
| `route_prefix` | Any string | `"/scim/v2"` |
| `tenancy` | `:single`, `:multi` | `:single` |
| `auth_method` | `:token`, `:oauth` | `:token` |
| `token` | String or `nil` | `nil` |
| `oauth_client_id` | String or `nil` | `nil` |
| `oauth_client_secret` | String or `nil` | `nil` |
| `devise_model` | String (class name) | `"User"` |
| `tenant_model` | String (class name) | `"DeviseScim::ScimTenant"` |
| `enable_groups` | `true`, `false` | `false` |
| `soft_delete` | `true`, `false` | `true` |
| `deprovision_manual_users` | `false`, `true`, `:error` | `false` |
| `user_exclusivity` | `:multiple`, `:one_to_one` | `:multiple` |
| `exclusivity_conflict` | `:error`, `:reassign` | `:error` |
| `adapter` | String (class name) or `nil` | `nil` |

Validation is in `Configuration#validate!` — add a corresponding guard there for any new attribute with a constrained value set.

## Migration template location

Templates live in `lib/generators/devise_scim/templates/*.rb.tt`.

| Template | Purpose |
|----------|---------|
| `add_scim_to_users.rb.tt` | Adds SCIM columns to the user table (single- and multi-tenant) |
| `create_scim_tenants.rb.tt` | Creates the `scim_tenants` table (built-in tenant, multi-tenant only) |
| `add_scim_to_tenant.rb.tt` | Adds SCIM columns to an existing tenant table (`--tenant-model` flag) |
| `create_scim_tenant_users.rb.tt` | Creates the `scim_tenant_users` join table (multi-tenant only) |
| `devise_scim.rb.tt` | Initializer |
| `application_scim_adapter.rb.tt` | Adapter skeleton (adapter generator) |

The multi-tenant templates reference the `tenant_fk_column` helper method defined in `InstallGenerator` — it resolves to `scim_tenant_id` for the built-in model or `<tenant_model_underscored>_id` for a custom one. The `add_scim_to_tenant.rb.tt` template guards every `add_column` with `unless column_exists?` so it is safe to run against an existing table.

## Auth strategies

```
lib/devise_scim/auth/
  base_strategy.rb    # extracts Bearer token from Authorization header
  token_strategy.rb   # compares against config.token (single) or ScimTenant.authenticate_token (multi)
  oauth_strategy.rb   # validates Doorkeeper access tokens
lib/devise_scim/middleware/authenticator.rb
```

`Authenticator` is a Rack middleware inserted early in the stack. It intercepts every request whose path starts with `route_prefix`, delegates to the appropriate strategy, and either sets `env["devise_scim.tenant"]` (multi-tenant) or returns a 401 SCIM error response. It also calls `warden.custom_failure!` so Warden does not swallow the 401.

Do not move auth logic into controllers — the middleware layer is the single authentication boundary.

## Filter system

```
lib/devise_scim/filter/
  parser.rb        # tokenizer + recursive descent parser → AST
  arel_visitor.rb  # walks AST → pure Arel conditions
```

The tokenizer uses explicit `m = regex.match(s)` calls rather than `gsub` to avoid `$&` clobbering. Keep it that way — `String#gsub` clears `$&` even for String patterns, which silently breaks the tokenizer.

`ArelVisitor` maps SCIM attribute names to AR column names and emits only Arel nodes — **no string interpolation, ever**. If you add a new filterable attribute, add it to the column mapping in `ArelVisitor` and add a spec in `spec/filter/arel_visitor_spec.rb`.

## Adding a new SCIM attribute

1. Add the field to the relevant struct in `lib/devise_scim/scim/user.rb` or `lib/devise_scim/scim/group.rb`.
2. Update `from_h` to parse the new attribute from the incoming hash.
3. Update `to_h` to serialize it in the outgoing hash.
4. Update `ScimAdapter#attributes_for_create`, `#attributes_for_update`, and `#to_scim` defaults in `lib/devise_scim/scim_adapter.rb` as appropriate.
5. If the attribute is filterable, add the SCIM→column mapping to `ArelVisitor`.
6. Add spec coverage: a unit spec for the struct, a request spec or shared-example assertion for the endpoint.

## Test app

`spec/internal/` is a [Combustion](https://github.com/pat/combustion) application loaded before the RSpec suite.

- **Schema:** `spec/internal/db/schema.rb` is loaded at suite start via `ActiveRecord::Schema.define`. Do not drop or rename existing tables or columns — doing so breaks specs that depend on those structures.
- **Routes:** `spec/internal/config/routes.rb` mounts three `scim_for` variants (default, groups-enabled, OAuth-enabled) to exercise conditional route generation. Keep all three.
- **Models:** `spec/internal/app/models/` contains the minimal `User` and `ScimGroup` models used by the suite.

When adding a new integration spec, use the existing models and schema. Add columns to the schema only when genuinely required, and add them to the end of the relevant `create_table` block.

## Commit message convention

- Imperative mood, under 72 characters on the subject line (`Add`, `Fix`, `Remove`, not `Added` / `Fixes`)
- Body explains **why**, not what — the diff already shows what changed
- Reference an issue number in the body when one exists (`Closes #123`)

Example:

```
Add :reassign exclusivity_conflict mode

Reassigning to a new tenant is safer than returning an error when an
IdP reprovisioning cycle runs across a tenant boundary. Closes #47.
```
