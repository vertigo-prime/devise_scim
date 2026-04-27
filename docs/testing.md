# Testing Guide

## Overview

`devise_scim` ships two test harnesses:

- **RSpec** — shared examples that exercise every endpoint in a real request spec, plus a `ScimHelpers` module for building payloads and headers
- **Minitest** — a `ScimAssertions` module with targeted assertion helpers for `ActionDispatch::IntegrationTest`

Both harnesses configure `DeviseScim` internally and reset after each example/test, so they do not interfere with your application's configuration.

---

## RSpec setup

Add one require to your `spec/rails_helper.rb` (or `spec/spec_helper.rb`):

```ruby
require "devise_scim/rspec"
```

This loads:
- `DeviseScim::RSpec::ScimHelpers`
- FactoryBot factories (`:scim_tenant`, `:scim_tenant_user`) — guarded by `defined?(FactoryBot)`, so they are a no-op if you are not using FactoryBot
- All three shared example groups

Make sure FactoryBot is required before `devise_scim/rspec` if you want the factories:

```ruby
require "factory_bot_rails"
require "devise_scim/rspec"
```

---

## Running the shared examples

Drop `it_behaves_like` inside any `RSpec.describe` block that has access to your Rails routes. A request spec is the natural home.

```ruby
# spec/requests/scim_users_spec.rb
require "rails_helper"

RSpec.describe "SCIM Users", type: :request do
  it_behaves_like "a SCIM Users endpoint", devise_model: User
end
```

```ruby
# spec/requests/scim_groups_spec.rb
require "rails_helper"

RSpec.describe "SCIM Groups", type: :request do
  it_behaves_like "a SCIM Groups endpoint"
end
```

```ruby
# spec/requests/scim_discovery_spec.rb
require "rails_helper"

RSpec.describe "SCIM discovery", type: :request do
  it_behaves_like "SCIM discovery endpoints"
end
```

Each shared example wraps itself in `before`/`after` blocks that:
1. Call `DeviseScim.configure` with `:single` tenancy, `:token` auth, and a freshly generated token
2. Call `DeviseScim.reset_configuration!` after the example finishes

This means the shared examples are safe to combine in the same suite with your own configuration.

---

## Available shared examples

| Name | What it covers | Required options |
|------|----------------|-----------------|
| `"a SCIM Users endpoint"` | GET/POST/PUT/PATCH/DELETE /Users, filter, auth, re-provisioning, multi-tenant context | `devise_model:` (the AR class) |
| `"a SCIM Groups endpoint"` | GET/POST/PATCH/DELETE /Groups, adapter delegation, 500 when `group_to_scim` not implemented | none |
| `"SCIM discovery endpoints"` | GET /ServiceProviderConfig, /Schemas, /ResourceTypes; groups conditionally included | none |

---

## `ScimHelpers` module

Include it in any `describe` block or RSpec configuration:

```ruby
RSpec.describe "my SCIM spec", type: :request do
  include DeviseScim::RSpec::ScimHelpers
  # ...
end
```

Or globally in `rails_helper.rb`:

```ruby
RSpec.configure do |config|
  config.include DeviseScim::RSpec::ScimHelpers, type: :request
end
```

**Methods:**

```ruby
# Parse a JSON response body into a Hash.
scim_json(response.body)
# => { "schemas" => [...], "id" => "1", ... }

# The configured route prefix (default: "/scim/v2").
scim_prefix
# => "/scim/v2"

# Authorization + Content-Type headers for a given token.
scim_auth_headers("my-token")
# => { "Authorization" => "Bearer my-token", "Content-Type" => "application/json" }

# Build a minimal valid POST /Users payload.
scim_user_payload(user_name: "alice@example.com")
# => { "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"], "userName" => "alice@example.com" }

# Extra keys are merged in:
scim_user_payload(user_name: "alice@example.com", "name" => { "givenName" => "Alice" })

# Wrap one or more operation hashes in a PatchOp envelope.
scim_patch_payload(
  scim_replace_op("active", false),
  scim_replace_op("userName", "new@example.com")
)
# => { "schemas" => ["urn:ietf:params:scim:api:messages:2.0:PatchOp"], "Operations" => [...] }

# Individual operation builders:
scim_replace_op("active", false)
# => { "op" => "replace", "path" => "active", "value" => false }

scim_add_op("emails", [{ "value" => "work@example.com", "type" => "work" }])
# => { "op" => "add", "path" => "emails", "value" => [...] }

scim_remove_op("phoneNumbers")
# => { "op" => "remove", "path" => "phoneNumbers" }
```

---

## Testing multi-tenant scenarios

The multi-tenant cases are included automatically as a nested `context "multi-tenant"` inside `"a SCIM Users endpoint"`. You do not need to enable or opt in to them — they run whenever you call `it_behaves_like "a SCIM Users endpoint"`.

The context creates a `DeviseScim::ScimTenant` record, calls `rotate_token!` to get a raw token, then reconfigures `DeviseScim` to `:multi` tenancy for those examples.

The multi-tenant context covers:

- Claiming an existing manual user on first SCIM provision (sets `scim_claimed_at` on the join record)
- 404 for a user not assigned to the requesting tenant
- `user_exclusivity: :one_to_one` with `exclusivity_conflict: :error` → 409
- `user_exclusivity: :one_to_one` with `exclusivity_conflict: :reassign` → reassigns the join record

If your spec database does not have the `scim_tenants` and `scim_tenant_users` tables (i.e., you have not run the multi-tenant migrations), the multi-tenant context will fail. Run `rails g devise_scim:install --multi-tenant` and `rails db:migrate` in your test environment, or skip the shared example and write targeted specs instead.

---

## Stubbing IdP payloads

Use `scim_user_payload` for standard fields, and merge extra keys for IdP-specific extensions.

**Okta-style POST /Users with name and phone:**

```ruby
payload = scim_user_payload(
  user_name: "alice@example.com",
  "name"   => { "givenName" => "Alice", "familyName" => "Smith", "formatted" => "Alice Smith" },
  "emails" => [{ "value" => "alice@example.com", "type" => "work", "primary" => true }],
  "phoneNumbers" => [{ "value" => "+14155550100", "type" => "work" }],
  "userType" => "Employee"
)

post "#{scim_prefix}/Users", params: payload.to_json, headers: scim_auth_headers(token)
```

**Complex PATCH with multiple operations:**

```ruby
payload = scim_patch_payload(
  scim_replace_op("active", false),
  scim_replace_op("name.givenName", "Alicia"),
  scim_add_op("phoneNumbers", [{ "value" => "+14155550101", "type" => "mobile" }])
)

patch "#{scim_prefix}/Users/#{user.id}", params: payload.to_json, headers: scim_auth_headers(token)
```

**Testing a filter-expression PATCH path (e.g., Okta email update):**

```ruby
payload = scim_patch_payload(
  scim_replace_op('emails[type eq "work"].value', "updated@example.com")
)

patch "#{scim_prefix}/Users/#{user.id}", params: payload.to_json, headers: scim_auth_headers(token)
expect(response).to have_http_status(:ok)
expect(user.reload.email).to eq("updated@example.com")
```

---

## Testing re-provisioning

The full create → DELETE → re-provision cycle:

```ruby
include DeviseScim::RSpec::ScimHelpers

let(:token) { "test-token" }
let(:headers) { scim_auth_headers(token) }

before do
  DeviseScim.configure do |c|
    c.tenancy     = :single
    c.auth_method = :token
    c.token       = token
  end
end

after { DeviseScim.reset_configuration! }

it "re-provisions a deleted SCIM user" do
  # Create.
  post "#{scim_prefix}/Users",
       params: scim_user_payload(user_name: "alice@example.com").to_json,
       headers: headers
  expect(response).to have_http_status(:created)
  user = User.find_by!(email: "alice@example.com")

  # Deprovision.
  delete "#{scim_prefix}/Users/#{user.id}", headers: headers
  expect(response).to have_http_status(:no_content)
  expect(user.reload.scim_active).to be(false)

  # Re-provision — same email, POST again.
  post "#{scim_prefix}/Users",
       params: scim_user_payload(user_name: "alice@example.com").to_json,
       headers: headers
  expect(response).to have_http_status(:created)
  expect(user.reload.scim_active).to be(true)
  # Record count should not increase — same row was re-activated.
  expect(User.where(email: "alice@example.com").count).to eq(1)
end
```

---

## Testing custom adapter behavior

**Verify `after_provision` is called:**

```ruby
it "calls after_provision on the adapter after create" do
  adapter = instance_double(ApplicationScimAdapter,
    attributes_for_create: { email: "alice@example.com" },
    after_provision:        nil,
    to_scim:                DeviseScim::Scim::User.new.tap { |u| u.id = "1"; u.user_name = "alice@example.com" }
  )

  allow(ApplicationScimAdapter).to receive(:new).and_return(adapter)

  post "#{scim_prefix}/Users",
       params: scim_user_payload(user_name: "alice@example.com").to_json,
       headers: headers

  expect(adapter).to have_received(:after_provision)
end
```

**Verify group delegation with a spy:**

```ruby
it "delegates POST /Groups to handle_group_create" do
  group_scim = DeviseScim::Scim::Group.new.tap { |g| g.id = "grp-1"; g.display_name = "Admins" }
  adapter_spy = instance_double(ApplicationScimAdapter,
    handle_group_create: nil,
    group_to_scim:       group_scim
  )

  allow(ApplicationScimAdapter).to receive(:new).and_return(adapter_spy)

  post "#{scim_prefix}/Groups",
       params: { "schemas" => [DeviseScim::Scim::GROUP_SCHEMA], "displayName" => "Admins" }.to_json,
       headers: headers

  expect(adapter_spy).to have_received(:handle_group_create)
  expect(response).to have_http_status(:created)
end
```

---

## Factories

`devise_scim/rspec` registers two FactoryBot factories when FactoryBot is available.

**`:scim_tenant`** — creates a `DeviseScim::ScimTenant` with a sequential name and token auth:

```ruby
tenant = create(:scim_tenant)
# tenant.name       => "Test Tenant 1"
# tenant.auth_method => "token"
# tenant.active      => true
# tenant.token_digest => nil  <-- no token yet
```

The factory does **not** call `rotate_token!`. Call it yourself to get the raw token:

```ruby
tenant = create(:scim_tenant)
raw_token = tenant.rotate_token!
headers = scim_auth_headers(raw_token)
```

**`:scim_tenant_user`** — creates a `DeviseScim::ScimTenantUser` join record:

```ruby
user   = create(:user)
tenant = create(:scim_tenant)

join = create(:scim_tenant_user, scim_tenant: tenant, user: user)
# join.active        => true
# join.provisioned_at => Time.current
```

You must pass `user:` explicitly — the factory has no default user association (it does not know your `User` class name).

---

## Minitest setup

Require the module and include it in your test class:

```ruby
# test/test_helper.rb  (or inside an individual test file)
require "devise_scim/minitest"
```

```ruby
class ScimTest < ActionDispatch::IntegrationTest
  include DeviseScim::Minitest::ScimAssertions
end
```

Or include it globally in `ActiveSupport::TestCase` / `ActionDispatch::IntegrationTest` via a concern in `test/test_helper.rb`.

---

## Minitest example

```ruby
require "test_helper"

class ScimUsersTest < ActionDispatch::IntegrationTest
  include DeviseScim::Minitest::ScimAssertions

  TOKEN = "minitest-scim-token"

  setup do
    DeviseScim.configure do |c|
      c.tenancy     = :single
      c.auth_method = :token
      c.token       = TOKEN
    end
  end

  teardown { DeviseScim.reset_configuration! }

  test "GET /scim/v2/Users returns a ListResponse" do
    User.create!(email: "alice@example.com")

    get "/scim/v2/Users", headers: scim_auth_headers(TOKEN)

    assert_scim_status(response, 200)
    assert_scim_content_type(response)
    assert_scim_list_response(response)
  end

  test "POST /scim/v2/Users creates a user" do
    payload = scim_user_payload(user_name: "bob@example.com")

    post "/scim/v2/Users",
         params: payload.to_json,
         headers: scim_auth_headers(TOKEN)

    assert_scim_status(response, 201)
    assert_scim_schema(response, DeviseScim::Scim::USER_SCHEMA)
    assert_equal "bob@example.com", scim_json(response)["userName"]
  end

  test "GET /scim/v2/Users returns 401 without auth" do
    get "/scim/v2/Users"
    assert_scim_status(response, 401)
    assert_scim_error(response, expected_status: 401)
  end

  test "DELETE deprovisioning sets scim_active to false" do
    user = User.create!(email: "carol@example.com", scim_source: "scim")

    delete "/scim/v2/Users/#{user.id}", headers: scim_auth_headers(TOKEN)

    assert_scim_status(response, 204)
    assert_equal false, user.reload.scim_active
  end
end
```

**Assertion reference:**

| Method | What it checks |
|--------|----------------|
| `assert_scim_status(response, status)` | `response.status == status` (coerces to string) |
| `assert_scim_content_type(response)` | `Content-Type` includes `application/scim+json` |
| `assert_scim_schema(response, schema)` | `body["schemas"]` includes the given URN |
| `assert_scim_list_response(response)` | Combines schema check with `totalResults` and `Resources` key presence |
| `assert_scim_error(response, expected_status: nil)` | `body["schemas"]` includes the SCIM error URN; optionally checks `body["status"]` |
| `scim_json(response)` | `JSON.parse(response.body)` |
| `scim_auth_headers(token)` | `{ "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }` |
| `scim_user_payload(user_name:, **attrs)` | Minimal User payload hash; extra keys are merged |
| `scim_patch_payload(*operations)` | PatchOp envelope hash |

---

## Testing against a real IdP

To test your SCIM endpoint with an actual IdP (Okta, Entra ID, JumpCloud) during local development, expose your Rails server over a public HTTPS tunnel:

```sh
# Cloudflare Tunnel (no account required for one-off tunnels):
cloudflared tunnel --url http://localhost:3000

# ngrok:
ngrok http 3000
```

Configure your IdP's SCIM connector to point at `https://<tunnel-host>/scim/v2`. Set a bearer token that matches `config.token` in your initializer (or create a `ScimTenant` record with a rotated token for multi-tenant mode).

> [!NOTE]
> Real IdPs send PATCH operations with filter-expression paths like `emails[type eq "work"].value`. Verify your adapter handles these before testing with an IdP — the gem's filter parser covers them, but your `attributes_for_update` or custom `to_scim` may need to account for the mapped attribute.
