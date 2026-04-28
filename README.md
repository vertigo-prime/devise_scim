# devise_scim

**SCIM 2.0 server for Rails + Devise**

## What is this?

`devise_scim` mounts a fully compliant SCIM 2.0 server inside any Rails + Devise application, handling user and group provisioning from identity providers like Okta, Azure AD, and OneLogin. Unlike most existing gems it supports both single- and multi-tenant architectures out of the box, is actively maintained, makes no external API calls (pure Ruby — no third-party SCIM SDK), and conforms strictly to RFC 7643 and RFC 7644.

## Requirements

- Ruby 3.2+
- Rails 7.0+
- Devise 4.9+
- bcrypt

## Doorkeeper

> [!IMPORTANT]
> `doorkeeper >= 5.6` is required **only** when using OAuth 2.0 authentication (`auth_method: :oauth`) or multi-tenant mode (`tenancy: :multi`). If the gem is missing, `DeviseScim::ConfigurationError` is raised at boot. Add `gem 'doorkeeper', '~> 5.6'` to your Gemfile **before** running the generator with `--oauth` or `--multi-tenant` — the generator performs a preflight check and will abort if it is absent.

## Installation

```ruby
# Gemfile
gem 'devise_scim'
```

```sh
bundle install
```

## Quick start: single-tenant, bearer token

**1. Run the generator**

```sh
rails g devise_scim:install User
```

This creates `config/initializers/devise_scim.rb` and the required migrations.

**2. Configure the generated initializer**

```ruby
# config/initializers/devise_scim.rb
DeviseScim.configure do |config|
  config.route_prefix = "/scim/v2"
  config.tenancy      = :single
  config.auth_method  = :token
  config.token        = ENV.fetch("SCIM_BEARER_TOKEN")
  config.devise_model = "User"
end
```

**3. Mount routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  scim_for :users
end
```

**4. Run migrations**

```sh
rails db:migrate
```

## Quick start: single-tenant, OAuth (Doorkeeper)

**Prerequisites:** add Doorkeeper to your Gemfile first.

```ruby
gem 'doorkeeper', '~> 5.6'
```

```sh
bundle install
rails g devise_scim:install User --oauth
rails db:migrate
```

The generator runs `rails g doorkeeper:install` for you if Doorkeeper's tables are not yet present (with your confirmation).

The token endpoint is mounted at `{route_prefix}/oauth/token`. Configure your IdP to POST client credentials there.

```ruby
# config/initializers/devise_scim.rb
DeviseScim.configure do |config|
  config.route_prefix        = "/scim/v2"
  config.tenancy             = :single
  config.auth_method         = :oauth
  config.oauth_client_id     = ENV.fetch("SCIM_CLIENT_ID")
  config.oauth_client_secret = ENV.fetch("SCIM_CLIENT_SECRET")
  config.devise_model        = "User"
end
```

## Quick start: multi-tenant (built-in ScimTenant)

```ruby
# Gemfile
gem 'doorkeeper', '~> 5.6'
```

```sh
bundle install
rails g devise_scim:install User --multi-tenant
rails db:migrate
```

Create tenants in the console (see [Tenant management](#tenant-management)).

## Quick start: multi-tenant (existing model)

Use this when you already have an `Org` (or similar) model that should act as the SCIM tenant.

```sh
rails g devise_scim:install User --multi-tenant --tenant-model=Org
rails db:migrate
```

Include the concern in your model:

```ruby
class Org < ApplicationRecord
  include DeviseScim::Concerns::ScimTenant
end
```

The generator adds only the columns that are missing — every `add_column` call in the migration is guarded with `unless column_exists?`.

## Generator reference

```sh
rails g devise_scim:install <ModelName> [--oauth] [--multi-tenant] [--tenant-model=ModelName]
```

| Flag | Effect |
|------|--------|
| `--oauth` | Configures OAuth 2.0 client-credentials auth; requires Doorkeeper |
| `--multi-tenant` | Generates tenant + join-table migrations; requires Doorkeeper |
| `--tenant-model=Org` | Uses existing `Org` model instead of the built-in `DeviseScim::ScimTenant` |

**Preflight behavior:** the generator checks whether `doorkeeper` appears in your Gemfile when `--oauth` or `--multi-tenant` is set. If Doorkeeper is in the Gemfile but its tables have not been generated yet, it prompts to run `rails g doorkeeper:install` before continuing.

**Action order:**

1. `preflight_check` — validates Doorkeeper presence
2. `copy_user_migration` — `add_scim_to_<table>.rb`
3. `copy_tenant_migrations` — `create_scim_tenants.rb` + `create_scim_tenant_users.rb` (or `add_scim_to_<tenant_table>.rb` if `--tenant-model` given)
4. `copy_initializer` — `config/initializers/devise_scim.rb`

> [!NOTE]
> The `devise_model` value in the generated initializer is automatically set from the generator argument — no manual editing needed.

## `rails g devise_scim:adapter`

Generates a pre-filled `ApplicationScimAdapter` that overrides the base adapter's defaults:

```sh
rails g devise_scim:adapter
# → app/scim/application_scim_adapter.rb
```

Then wire it up:

```ruby
config.adapter = "ApplicationScimAdapter"
```

## Configuration reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `route_prefix` | `String` | `"/scim/v2"` | Mount path for all SCIM endpoints |
| `tenancy` | `:single` \| `:multi` | `:single` | Single or multi-tenant mode |
| `auth_method` | `:token` \| `:oauth` | `:token` | Authentication strategy |
| `token` | `String\|nil` | `nil` | Bearer token (single-tenant token auth only) |
| `oauth_client_id` | `String\|nil` | `nil` | OAuth client ID (single-tenant OAuth only) |
| `oauth_client_secret` | `String\|nil` | `nil` | OAuth client secret (single-tenant OAuth only) |
| `devise_model` | `String` | `"User"` | Devise model class name |
| `tenant_model` | `String` | `"DeviseScim::ScimTenant"` | Tenant model class name (multi-tenant only) |
| `enable_groups` | `Boolean` | `false` | Mount `/Groups` endpoints |
| `soft_delete` | `Boolean` | `true` | `true` = set `scim_active=false` on DELETE; `false` = destroy record |
| `deprovision_manual_users` | `false` \| `true` \| `:error` | `false` | Behaviour when DELETE targets a manually-created user |
| `user_exclusivity` | `:multiple` \| `:one_to_one` | `:multiple` | Whether a user may belong to multiple tenants (multi-tenant only) |
| `exclusivity_conflict` | `:error` \| `:reassign` | `:error` | Conflict resolution when `user_exclusivity: :one_to_one` (multi-tenant only) |
| `adapter` | `String\|nil` | `nil` | Adapter class name; uses built-in defaults when `nil` |

## Routes reference

`scim_for :users` mounts the following routes under `route_prefix` (default `/scim/v2`):

```
GET    /scim/v2/Users
POST   /scim/v2/Users
GET    /scim/v2/Users/:id
PUT    /scim/v2/Users/:id
PATCH  /scim/v2/Users/:id
DELETE /scim/v2/Users/:id

# when enable_groups: true
GET    /scim/v2/Groups
POST   /scim/v2/Groups
GET    /scim/v2/Groups/:id
PUT    /scim/v2/Groups/:id
PATCH  /scim/v2/Groups/:id
DELETE /scim/v2/Groups/:id

# when auth_method: :oauth
POST   /scim/v2/oauth/token

# always present
GET    /scim/v2/ServiceProviderConfig
GET    /scim/v2/Schemas
GET    /scim/v2/ResourceTypes
```

Override the prefix with the `at:` option:

```ruby
scim_for :users, at: "/api/scim/v2"
```

## Tenant management

```ruby
# Create a tenant
tenant = DeviseScim::ScimTenant.create!(name: "Acme Corp", auth_method: "token", active: true)

# Issue a bearer token — only returned once, store it securely
raw_token = tenant.rotate_token!
```

> [!WARNING]
> `rotate_token!` returns the raw token **exactly once**. Only the bcrypt digest is persisted. Store the raw token immediately (e.g. copy it to your IdP's configuration) — it cannot be retrieved again. Call `rotate_token!` again to issue a replacement, which invalidates the previous token.

```ruby
# Link to a Doorkeeper OAuth application (OAuth auth method)
app = Doorkeeper::Application.find_by(name: "Acme IdP")
tenant.update!(doorkeeper_application: app, auth_method: "oauth")

# Check active status
tenant.scim_active? # => true / false

# Deactivate (blocks all further SCIM requests for this tenant)
tenant.update!(active: false)
```

## User source tracking and deprovision

The `scim_source` column on the user record tracks how the user was created:

| Value | Meaning |
|-------|---------|
| `"scim"` | Created or claimed via SCIM provisioning |
| `nil` | Created manually (e.g. sign-up, seed data, console) |

The `deprovision_manual_users` config controls what happens when a DELETE request targets a user with `scim_source: nil`:

| `scim_source` | `deprovision_manual_users` | Result |
|---------------|---------------------------|--------|
| `"scim"` | any | Deprovision (soft-delete or destroy) — 204 No Content |
| `nil` | `false` (default) | Skip silently — 200 OK |
| `nil` | `true` | Deprovision — 204 No Content |
| `nil` | `:error` | 409 Conflict |

## Re-provisioning

When a POST to `/Users` matches a user with `scim_active: false` (previously deprovisioned), the gem re-provisions them rather than returning a conflict:

- `scim_active` is set to `true`
- `scim_deprovisioned_at` is cleared
- `after_provision` callback is invoked on the adapter

This allows IdPs to deprovision and later re-provision the same user without manual intervention.

## User exclusivity (multi-tenant)

Available only in `tenancy: :multi` mode.

| `user_exclusivity` | Behaviour |
|--------------------|-----------|
| `:multiple` (default) | A user may belong to any number of tenants simultaneously |
| `:one_to_one` | A user may belong to at most one tenant at a time |

When `:one_to_one` is set and a POST `/Users` matches a user already assigned to a different tenant, `exclusivity_conflict` controls the outcome:

| `exclusivity_conflict` | Outcome |
|------------------------|---------|
| `:error` (default) | 409 Conflict |
| `:reassign` | Deactivates the old tenant join record, creates a new one for the requesting tenant |

## Group provisioning

The gem handles the SCIM protocol layer for groups; business logic lives in your adapter. When `enable_groups: true`, implement the following methods in your `ApplicationScimAdapter`:

```ruby
def handle_group_create  # called on POST /Groups
def handle_group_update  # called on PUT/PATCH /Groups/:id
def handle_group_destroy # called on DELETE /Groups/:id
def group_to_scim        # returns a DeviseScim::Scim::Group instance
```

The base adapter raises `NotImplementedError` for `group_to_scim` and no-ops the other callbacks — groups succeed at the protocol level until you implement the methods. See `docs/custom_adapter.md` for a full walkthrough.

## Test harness

The gem ships a test harness you can include in your host app's test suite.

**RSpec:**

```ruby
# spec/rails_helper.rb
require "devise_scim/rspec"
```

```ruby
RSpec.describe "SCIM Users" do
  it_behaves_like "a SCIM Users endpoint", devise_model: User
end
```

**Minitest:**

```ruby
require "devise_scim/minitest"

class ScimUsersTest < ActionDispatch::IntegrationTest
  include DeviseScim::Minitest::ScimAssertions
  # ...
end
```

The shared RSpec example covers index, show, create, replace, PATCH update, delete, re-provisioning, authentication enforcement, and multi-tenant scenarios. See `docs/testing.md` for available options and writing custom assertions.

## License

MIT. Used at your own risk. No liability is held by the author.

## Contributing

This gem was developed with significant assistance from Claude (Anthropic). Contributions and audits welcome, AI or otherwise.

1. Please follow the [contributing guidelines](docs/contributng.md) for submitting pull requests and reporting issues.
2. Ensure your code adheres to the [code of conduct](CODE_OF_CONDUCT.md) and is tested with the provided test harness.
