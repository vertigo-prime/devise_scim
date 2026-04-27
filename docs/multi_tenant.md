# Multi-Tenancy Guide

## Overview

In multi-tenant mode (`config.tenancy = :multi`), each Identity Provider (IdP) is represented as a **tenant** — an AR record that holds its own credentials and configuration. Every SCIM request arrives with a credential (Bearer token or OAuth token) that the middleware resolves to a specific tenant record before the request reaches any controller.

All database operations are then scoped to that tenant via the `scim_tenant_users` join table. A single application can serve many IdPs simultaneously; each sees only its own users and cannot see or modify records provisioned by another tenant.

Key design properties:

- One tenant per IdP — credentials are stored per tenant, not in environment variables.
- `scim_tenant_users` is the authority for membership — a user exists in a tenant's scope only if a matching active join record exists.
- Each tenant assigns its own `scim_uid` (the IdP's external ID) — the UID lives on the join record so the same user can carry different external IDs across tenants.

---

## Schema Overview

Three tables work together:

**`users`** — your application's Devise user table, extended with SCIM tracking columns:

| Column | Type | Purpose |
|---|---|---|
| `scim_uid` | string | IdP's external ID (single-tenant only; in multi-tenant mode this lives on the join) |
| `scim_source` | string | `"scim"` if provisioned via SCIM, `nil` for manually created users |
| `scim_active` | boolean | Whether the user is active |
| `scim_deprovisioned_at` | datetime | Timestamp of last soft-delete |
| `scim_raw` | text / jsonb | Raw SCIM payload from last write (debugging aid) |

**`scim_tenants`** — one row per IdP:

| Column | Type | Purpose |
|---|---|---|
| `name` | string | Human-readable label |
| `auth_method` | string | `"token"` or `"oauth"` |
| `token_digest` | string | BCrypt digest of the Bearer token |
| `active` | boolean | Whether this tenant is accepting requests |
| `doorkeeper_application_id` | integer | FK to `oauth_applications` (OAuth mode) |

**`scim_tenant_users`** — the join table that scopes all operations:

| Column | Type | Purpose |
|---|---|---|
| `scim_tenant_id` | bigint | FK to the tenant (or custom FK — see below) |
| `user_id` | bigint | FK to your users table |
| `scim_uid` | string | The IdP's external ID for this user **within this tenant** |
| `provisioned_at` | datetime | When the user was first provisioned by this tenant |
| `scim_claimed_at` | datetime | Set when an existing user (not net-new) was claimed by this tenant |
| `active` | boolean | Whether this assignment is currently active |
| `scim_raw` | text / jsonb | Raw SCIM payload from last write |

`scim_uid` lives on the join table — not on `users` — so the same user can have different external IDs per tenant, and a user's presence in one tenant's scope has no bearing on another's.

There are two unique indexes on `scim_tenant_users`:

- `(scim_tenant_id, user_id)` — one join record per user per tenant
- `(scim_tenant_id, scim_uid) WHERE scim_uid IS NOT NULL` — prevents duplicate UID assignment within a tenant

---

## Built-In ScimTenant Model

For most applications the built-in `DeviseScim::ScimTenant` is all you need.

**1. Generate and migrate:**

```bash
rails g devise_scim:install User --multi-tenant
rails db:migrate
```

This generates:

- `db/migrate/add_scim_to_users.rb` — adds SCIM columns to your users table
- `db/migrate/create_scim_tenants.rb` — creates `scim_tenants`
- `db/migrate/create_scim_tenant_users.rb` — creates `scim_tenant_users`
- `config/initializers/devise_scim.rb` — pre-configured for multi-tenant mode

The default `config.tenant_model` is `"DeviseScim::ScimTenant"`. You do not need to set it explicitly.

**2. Create a tenant and obtain a token:**

```ruby
# Rails console
tenant = DeviseScim::ScimTenant.create!(name: "Acme Corp", auth_method: "token")
raw_token = tenant.rotate_token!
# => "a3f8c2d1e9b7..."   — store this securely; it will not be shown again
```

> [!WARNING]
> `rotate_token!` returns the raw token exactly once. Store it immediately and provide it to your IdP. The raw value is never persisted — only the BCrypt digest is stored in `token_digest`.

---

## Custom Tenant Model

If you already have an AR model representing organizations, accounts, or workspaces, you can use it as the SCIM tenant instead of `DeviseScim::ScimTenant`.

**1. Include the concern in your existing model:**

```ruby
# app/models/org.rb
class Org < ApplicationRecord
  include DeviseScim::Concerns::ScimTenant
  # ... rest of your model
end
```

**2. Run the generator with `--tenant-model`:**

```bash
rails g devise_scim:install User --multi-tenant --tenant-model=Org
rails db:migrate
```

The generator creates an **additive** migration that only adds columns that do not already exist:

```ruby
class AddScimToOrgs < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:orgs, :token_digest)
      add_column :orgs, :token_digest, :string
    end
    unless column_exists?(:orgs, :auth_method)
      add_column :orgs, :auth_method, :string, null: false, default: "token"
    end
    unless column_exists?(:orgs, :doorkeeper_application_id)
      add_column :orgs, :doorkeeper_application_id, :bigint
      add_foreign_key :orgs, :oauth_applications,
                      column: :doorkeeper_application_id, on_delete: :nullify
    end
  end
end
```

It also updates the initializer to set:

```ruby
config.tenant_model = "Org"
```

**FK column derivation:** the join table's tenant FK column is derived by underscoring the model name and appending `_id`:

| `tenant_model` | FK column on `scim_tenant_users` |
|---|---|
| `DeviseScim::ScimTenant` (default) | `scim_tenant_id` |
| `Org` | `org_id` |
| `MyAccount` | `my_account_id` |

The `tenant_fk_column` helper in the controller (`"#{tenant_model.demodulize.underscore}_id"`) performs this derivation at runtime.

> [!IMPORTANT]
> Your custom tenant model must respond to `active` (for `scim_active?`) and `token_digest` (for `authenticate_token`). If your model uses a different column for the human-readable name, override `scim_tenant_label_column` — see below.

---

## ScimTenant Concern API

These methods are mixed into any model that `include DeviseScim::Concerns::ScimTenant`.

### `authenticate_token(raw_token)` — class method

```ruby
DeviseScim::ScimTenant.authenticate_token("a3f8c2d1e9b7...")
# => #<DeviseScim::ScimTenant id=1 name="Acme Corp"> or nil
```

Queries all records where `auth_method = "token"` and `active = true`, then BCrypt-compares each `token_digest` against `raw_token`. Returns the matching record or `nil`.

Called by the middleware's `TokenStrategy` on every SCIM request in multi-tenant mode.

### `rotate_token!` — instance method

```ruby
raw = tenant.rotate_token!
# => "a3f8c2d1e9b7..."
```

Generates a 64-character hex token, BCrypt-hashes it into `token_digest`, and saves the record. Returns the raw token. The raw value is not stored anywhere — if you lose it, call `rotate_token!` again to issue a new one.

### `scim_active?` — instance method

```ruby
tenant.scim_active?  # => true / false
```

Delegates to the `active` column. Override if your model uses a different boolean column.

### `scim_tenant_label_column` — class method

```ruby
# Default:
def self.scim_tenant_label_column
  :name
end
```

Override in your model to point at the column used as the human-readable label (validated for presence on save):

```ruby
class Org < ApplicationRecord
  include DeviseScim::Concerns::ScimTenant

  def self.scim_tenant_label_column
    :display_name
  end
end
```

---

## Console Commands

**Create a tenant and obtain its token:**

```ruby
tenant = DeviseScim::ScimTenant.create!(name: "Acme Corp", auth_method: "token")
raw = tenant.rotate_token!
puts raw   # copy to clipboard — shown once only
```

**Rotate a token without downtime:**

```ruby
tenant = DeviseScim::ScimTenant.find_by!(name: "Acme Corp")
new_raw = tenant.rotate_token!
# 1. Update token_digest is persisted immediately.
# 2. Update the IdP with new_raw.
# 3. Old token is now invalid — there is no grace period.
```

> [!WARNING]
> Token rotation is instantaneous. The old token is invalid as soon as `rotate_token!` returns. Update the IdP before rotating if you need zero downtime, or accept a brief authentication failure window.

**Link a tenant to a Doorkeeper application (OAuth mode):**

```ruby
app = Doorkeeper::Application.find_by!(name: "Acme SCIM")
tenant = DeviseScim::ScimTenant.find_by!(name: "Acme Corp")
tenant.update!(auth_method: "oauth", doorkeeper_application: app)
```

**List all active tenants:**

```ruby
DeviseScim::ScimTenant.where(active: true).map { |t| [t.id, t.name, t.auth_method] }
```

**Deactivate a tenant:**

```ruby
DeviseScim::ScimTenant.find_by!(name: "Acme Corp").update!(active: false)
# The middleware will reject all requests from this tenant's credentials immediately.
```

---

## User Scoping

In multi-tenant mode every read and write goes through `tenant_scope`, which uses a pure-Arel join — no string interpolation:

```ruby
# ApplicationController#tenant_scope (simplified)
stu  = ScimTenantUser.arel_table
dm   = devise_model.arel_table
join = dm.join(stu).on(stu[:user_id].eq(dm[:id])).join_sources
cond = stu[tenant_fk_column].eq(current_scim_tenant.id).and(stu[:active].eq(true))
devise_model.joins(join).where(cond)
```

Consequences:

- `GET /Users` returns only users with an **active** join record for the current tenant.
- `GET /Users/:id`, `PUT /Users/:id`, `PATCH /Users/:id`, `DELETE /Users/:id` — if the user exists in the database but has no active join for this tenant, the controller raises `NotFound` and responds with 404. A tenant cannot read or modify another tenant's users.
- Deprovisioning (`DELETE /Users/:id`) sets `active = false` on the join record, not on the user row itself (unless `soft_delete` is also true, in which case both are updated).

---

## User Exclusivity Scenarios

The `user_exclusivity` and `exclusivity_conflict` settings control what happens when `POST /Users` arrives for a user who already has a join record in a **different** tenant.

| `user_exclusivity` | `exclusivity_conflict` | Scenario: user is in tenant B, tenant A provisions them | Result |
|---|---|---|---|
| `:multiple` (default) | any | User exists in tenant B | New join created; user now active in both A and B |
| `:one_to_one` | `:error` (default) | User exists in tenant B | 409 Conflict — user belongs to another tenant |
| `:one_to_one` | `:reassign` | User exists in tenant B | Tenant B's join set to `active=false`; new active join created for tenant A |

**`:multiple` (default):** a user may belong to any number of tenants simultaneously. This is the right choice when your users may legitimately exist in multiple organizations, or when you do not want SCIM provisioning in one IdP to affect another.

**`:one_to_one`:** enforces that a user belongs to at most one tenant at a time. Use this when each user maps to exactly one organization.

When `:one_to_one` + `:reassign`: the old join record is not deleted — it is deactivated (`active = false`). This preserves the audit trail. If the user is later re-provisioned by tenant B, a new join record is created.

Note: "belongs to another tenant" means there is an `active = true` join record with a different tenant FK. A user with only inactive join records (previously deprovisioned) is treated as unowned.

---

## Claiming Existing Users

When `POST /Users` arrives and no matching user exists in the database, the controller creates a new user record and an active join record. This is the standard "net-new" provisioning path.

When `POST /Users` arrives and a user with that email already exists but has **no** active join for this tenant (e.g., the user was created manually in your app), the controller **claims** the user:

1. Sets `user.scim_source = "scim"` if the column exists.
2. Saves the user if changed.
3. Creates a new `ScimTenantUser` join record with `active = true`, `provisioned_at = Time.current`, and `scim_claimed_at = Time.current`.
4. Calls `adapter.after_provision`.

`scim_claimed_at` being set indicates the user was claimed from a pre-existing account rather than created fresh. `provisioned_at` is always the timestamp of the first active assignment by this tenant.

A claimed user is indistinguishable from a net-new user from the IdP's perspective — the response is HTTP 201 with the full SCIM user representation either way.

Claiming an already-active member (join record exists and `active = true` for the same tenant) raises a 409 Conflict.

---

## Recommended UI Scaffold

A minimal tenant management UI typically needs:

- **Create form** — `name`, `auth_method` (`"token"` or `"oauth"`). On save, call `rotate_token!` and display the raw token in a one-time reveal modal. Never show it again.
- **Token rotate button** — confirm intent, call `rotate_token!`, display raw token in a one-time reveal, remind the admin to update the IdP immediately.
- **Doorkeeper app selector** — shown only when `auth_method = "oauth"`. Renders a `<select>` over `Doorkeeper::Application.all` and saves `doorkeeper_application_id`.
- **Active toggle** — `update!(active: false/true)`. Deactivating immediately blocks all requests from that tenant's credentials.

There is no built-in UI — the gem is intentionally a pure API layer. The above is a starting point for a standard Rails controller + views or a Hotwire component.
