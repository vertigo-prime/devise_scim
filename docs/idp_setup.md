# IdP Setup Guide

## Overview

`devise_scim` implements the **SCIM 2.0 server** (RFC 7643 / RFC 7644). Your application is the SCIM provider; the Identity Provider (Okta, Microsoft Entra, JumpCloud, etc.) is the SCIM client.

The IdP initiates all communication by pushing user lifecycle events to your app's SCIM endpoints. Your app never calls out to the IdP — it only responds to inbound HTTP requests from it.

Typical lifecycle events:

- User created in the IdP directory → `POST /scim/v2/Users`
- User profile updated → `PATCH /scim/v2/Users/:id`
- User deactivated or removed → `DELETE /scim/v2/Users/:id` or `PATCH` with `active=false`
- Group membership changed → `PATCH /scim/v2/Groups/:id` (when `enable_groups: true`)

---

## Obtaining Credentials

### Bearer token (multi-tenant)

```ruby
# Rails console
tenant = DeviseScim::ScimTenant.create!(name: "Acme Corp", auth_method: "token")
raw_token = tenant.rotate_token!
# => "a3f8c2d1e9b7..."   — copy this now; it will not be shown again
```

Provide `raw_token` to the IdP as the Bearer token. The BCrypt digest is stored in `token_digest`; the raw value is never persisted.

### Bearer token (single-tenant)

Set the token in an environment variable and reference it in the initializer:

```ruby
# config/initializers/devise_scim.rb
config.token = ENV.fetch("SCIM_BEARER_TOKEN", nil)
```

Generate a token:

```bash
ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

Set `SCIM_BEARER_TOKEN` in your deployment environment and in the IdP's SCIM configuration.

### OAuth 2.0 (client credentials grant)

OAuth is only available when `auth_method: :oauth` and Doorkeeper >= 5.6 is installed.

```ruby
# Rails console
app = Doorkeeper::Application.create!(
  name: "Acme SCIM",
  uid: SecureRandom.hex(8),
  secret: SecureRandom.hex(16),
  redirect_uri: "",
  scopes: ""
)
puts "client_id:     #{app.uid}"
puts "client_secret: #{app.secret}"
```

In multi-tenant OAuth mode, associate the application with the tenant:

```ruby
tenant.update!(auth_method: "oauth", doorkeeper_application: app)
```

Provide `client_id` and `client_secret` to the IdP.

---

## Okta Setup

1. In Okta Admin, go to **Applications → Applications → Browse App Catalog**.
2. Search for **SCIM 2.0** or open your existing app and navigate to **Provisioning → Configure API Integration**.
3. Check **Enable API Integration**.
4. Set the fields:

   | Field | Value |
   |---|---|
   | SCIM connector base URL | `https://yourapp.com/scim/v2` |
   | Unique identifier field for users | `userName` |
   | Authentication Mode | `HTTP Header` (Bearer) or `OAuth` |
   | Authorization / Bearer Token | the raw token from `rotate_token!` |

5. Click **Test API Credentials** — expect HTTP 200 with a `ServiceProviderConfig` response.
6. Under **Provisioning → To App**, enable:
   - **Create Users**
   - **Update User Attributes**
   - **Deactivate Users**
   - **Push Groups** (only if `enable_groups: true` in your config)

**Attribute mapping** (Okta attribute → SCIM attribute → your model column via the adapter):

| Okta attribute | SCIM attribute | Default AR column |
|---|---|---|
| `login` / `email` | `userName` | `email` |
| `firstName` | `name.givenName` | `first_name` |
| `lastName` | `name.familyName` | `last_name` |
| `active` | `active` | `scim_active` |

**What Okta sends for each operation:**

- **CREATE** — `POST /Users` with a full SCIM user payload (`schemas`, `userName`, `name`, `emails`, `active`).
- **UPDATE** — `PATCH /Users/:id` with a `Operations` array. Each operation has an `op` (replace/add/remove), optional `path`, and `value`.
- **DEACTIVATE** — `PATCH /Users/:id` with `{ op: "replace", path: "active", value: false }`, or `DELETE /Users/:id` depending on your Okta app settings.

---

## Microsoft Entra (Azure AD) Setup

1. In the Azure portal, go to **Azure Active Directory → Enterprise Applications → New Application → Create your own application → Non-gallery**.
2. Name the app (e.g., "YourApp SCIM"), select **Integrate any other application you don't find in the gallery**.
3. Navigate to **Provisioning → Get started → Provisioning Mode: Automatic**.
4. Under **Admin Credentials**:

   | Field | Value |
   |---|---|
   | Tenant URL | `https://yourapp.com/scim/v2` |
   | Secret Token | the raw Bearer token |

5. Click **Test Connection** — expect a success message.
6. Expand **Mappings** to review attribute mappings. Defaults are reasonable; adjust if your column names differ.

**Entra-specific notes:**

- Entra sends `externalId` alongside `userName`. The gem maps `externalId` → `scim_uid` in single-tenant mode (the `ArelVisitor`'s `SCIM_TO_AR` table maps `"externalId"` → `"scim_uid"`).
- Entra performs **soft-match** on first sync: if a user with matching `userName` (email) already exists in your app, Entra will attempt to link to that record rather than create a duplicate. The gem's claiming behavior (see the multi-tenancy guide) complements this — the user is claimed and `scim_claimed_at` is set.
- Entra's provisioning cycle runs on a ~40-minute schedule by default. Use **Provision on demand** in the Azure portal to test individual users immediately.

---

## OAuth Token Endpoint

Available only when `config.auth_method = :oauth`.

```
POST {route_prefix}/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&client_id=CLIENT_ID&client_secret=CLIENT_SECRET
```

Example:

```bash
curl -X POST https://yourapp.com/scim/v2/oauth/token \
  -d "grant_type=client_credentials" \
  -d "client_id=abc123" \
  -d "client_secret=xyz456"
```

Doorkeeper handles the response format (RFC 6749):

```json
{
  "access_token": "TOKEN",
  "token_type": "Bearer",
  "expires_in": 7200,
  "created_at": 1700000000
}
```

The IdP then uses the returned `access_token` as the Bearer token for subsequent SCIM requests. Tokens expire per Doorkeeper's configuration (`access_token_expires_in`).

The OAuth token endpoint is mounted by the router only when `auth_method == :oauth` — it does not appear in the route table for token-authenticated apps.

---

## Bearer Token Setup

**Single-tenant pattern:**

```ruby
# config/initializers/devise_scim.rb
config.auth_method = :token
config.token = ENV.fetch("SCIM_BEARER_TOKEN", nil)
```

Set `SCIM_BEARER_TOKEN` in your production environment (Heroku config vars, AWS SSM, Kubernetes secret, etc.). Never commit the raw token to source control.

The middleware compares the incoming Bearer token against `config.token` using `ActiveSupport::SecurityUtils.secure_compare` — a timing-safe comparison that prevents timing-oracle attacks.

**Rotating tokens without downtime (single-tenant):**

There is no grace period for single-tenant token auth — the new value in `config.token` is active as soon as the process restarts. To avoid a gap:

1. Generate a new token.
2. Update `SCIM_BEARER_TOKEN` in your deployment environment and deploy (process restarts with new token).
3. Update the token in the IdP.
4. The window where the old token is rejected and the new one not yet entered in the IdP is typically seconds — most IdPs retry on 401.

**Multi-tenant token rotation:**

See the `rotate_token!` documentation in the multi-tenancy guide. The new token_digest is active immediately after `rotate_token!` returns; update the IdP promptly.

---

## Testing Connectivity

Before configuring an IdP, verify your endpoints respond correctly.

**Discovery:**

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" \
  https://yourapp.com/scim/v2/ServiceProviderConfig | jq .
```

Expected: HTTP 200, `Content-Type: application/scim+json`, body with `schemas` array.

**List users:**

```bash
curl -s -H "Authorization: Bearer YOUR_TOKEN" \
  "https://yourapp.com/scim/v2/Users" | jq .
```

Expected: HTTP 200, `ListResponse` with `totalResults`, `startIndex`, `itemsPerPage`, `Resources`.

**Create a user:**

```bash
curl -s -X POST https://yourapp.com/scim/v2/Users \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/scim+json" \
  -d '{
    "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"],
    "userName": "test@example.com",
    "name": { "givenName": "Test", "familyName": "User" },
    "active": true
  }' | jq .
```

Expected: HTTP 201, full SCIM user representation.

**Filter users:**

```bash
curl -s -G -H "Authorization: Bearer YOUR_TOKEN" \
  https://yourapp.com/scim/v2/Users \
  --data-urlencode 'filter=userName eq "test@example.com"' | jq .
```

> [!NOTE]
> All SCIM endpoints respond with `Content-Type: application/scim+json`. Some HTTP clients or test tools may show a warning if they expect `application/json` — this is correct per RFC 7644.

---

## Okta SCIM Test Harness

Okta provides a Runscope-based SCIM 2.0 test harness that validates your provider before activating provisioning in production. Run it against a staging environment exposed via a public URL (e.g. `ngrok http 3000`).

**How to run:**

1. In Okta Admin → your SCIM app → **Provisioning** tab → **Test API Credentials** — verifies the base URL and token before any test.
2. Navigate to the [Okta SCIM Test Suite](https://developer.okta.com/docs/guides/scim-provisioning-integration-test/) and import the Runscope test bucket for SCIM 2.0.
3. Set environment variables in Runscope:
   - `base_url` — e.g. `https://abc123.ngrok-free.app/scim/v2`
   - `auth_header` — `Bearer YOUR_TOKEN`
4. Run the full test suite.

**Expected results against `devise_scim` v0.1.0:**

| Test group | Result | Notes |
|---|---|---|
| Authentication | Pass | 401 on missing/invalid token |
| User create (`POST /Users`) | Pass | Returns 201 with `id`, full user representation |
| User read (`GET /Users/:id`) | Pass | Returns 200 with correct schema |
| User list (`GET /Users`) | Pass | Pagination via `startIndex` + `count`; filter via `userName eq "..."` |
| User update (`PUT /Users/:id`) | Pass | Full replace |
| User patch (`PATCH /Users/:id`) | Pass | `replace` op on `active`, `name.*`, `emails` |
| User deprovision (`PATCH active=false`) | Pass | Calls `after_deprovision`; `active` returns false on next GET |
| User reprovision (`PATCH active=true`) | Pass | Re-activates; `scim_source` preserved |
| ServiceProviderConfig | Pass | Correct `schemas`, `filter.supported`, `patch.supported` |
| Schemas discovery | Pass | Returns User and Group schema definitions |

> [!NOTE]
> Group tests require a `ScimAdapter` that implements `handle_group_create`, `handle_group_update`, and `handle_group_destroy`. The default adapter returns `501 Not Implemented` for these, which Okta's harness flags as a warning (not a failure) when Groups provisioning is disabled in the Okta app.

---

## SCIM Filter Support

The gem implements a full recursive-descent SCIM filter parser (RFC 7644 §3.4.2.2).

**Supported comparison operators:**

| Operator | Meaning | Example |
|---|---|---|
| `eq` | Equal | `userName eq "alice@example.com"` |
| `ne` | Not equal | `active ne true` |
| `co` | Contains | `userName co "example"` |
| `sw` | Starts with | `userName sw "alice"` |
| `ew` | Ends with | `userName ew ".com"` |
| `pr` | Present (not null) | `userName pr` |
| `gt` | Greater than | `meta.created gt "2024-01-01"` |
| `ge` | Greater than or equal | `meta.created ge "2024-01-01"` |
| `lt` | Less than | `meta.created lt "2025-01-01"` |
| `le` | Less than or equal | `meta.created le "2025-01-01"` |

**Logical operators:** `and`, `or` (standard precedence — `and` binds tighter than `or`).

**Supported SCIM attributes and their AR column mappings:**

| SCIM attribute | AR column |
|---|---|
| `userName` | `email` |
| `externalId` | `scim_uid` |
| `active` | `scim_active` |
| `id` | `id` |
| `emails` / `emails.value` | `email` |
| `name.givenName` | `first_name` |
| `name.familyName` | `last_name` |

Filters referencing unmapped or non-existent columns respond with HTTP 400 and SCIM error type `invalidFilter`.

---

## Common Issues

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 Unauthorized` on all requests | Token mismatch or tenant inactive | Verify the raw token in the IdP matches the one from `rotate_token!`. Check `tenant.active?`. In single-tenant mode, verify `SCIM_BEARER_TOKEN` env var is set and the process has restarted. |
| `401` with correct token | Warden intercepting the middleware's 401 | This is handled internally by `warden.custom_failure!`. If you see it in a custom setup, ensure the `DeviseScim::Middleware::Authenticator` is mounted before Warden. |
| `404` for a user that exists | User is outside this tenant's scope | In multi-tenant mode, `GET /Users/:id` returns 404 if the user has no active `scim_tenant_users` record for the current tenant. Check the join table. |
| `409 Conflict` on `POST /Users` for a user that was deprovisioned | User is deprovisioned but still `scim_active = false` | In single-tenant mode the gem re-provisions deprovisioned users. In multi-tenant mode it re-creates the join record. Verify the user's `scim_active` column and the join record's `active` flag. |
| `409 Conflict` on `POST /Users` for a user in another tenant | `user_exclusivity: :one_to_one` and `exclusivity_conflict: :error` | Either set `exclusivity_conflict: :reassign` to move the user, or set `user_exclusivity: :multiple` to allow shared membership. |
| `400 invalidFilter` | Filter uses an unsupported attribute or malformed syntax | Check the `SCIM_TO_AR` mapping in `ArelVisitor`. The attribute must map to a column that exists on your model. |
| `500` on filter with valid attribute | Column exists in the mapping but not in the database | Run `rails db:migrate`. The `add_scim_to_users` migration adds `first_name`/`last_name` only if they're present on the model. |
| Okta "Test API Credentials" fails | Base URL includes a trailing slash, or route prefix mismatch | Ensure the base URL ends with `/scim/v2` (no trailing slash) and matches `config.route_prefix`. |
| Entra creates duplicate users | Soft-match not firing | Entra matches on `userName`. Ensure your `userName` SCIM attribute maps to the same value as your `email` column — the default adapter uses `record.email` for `userName`. |
