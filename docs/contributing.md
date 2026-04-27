# Contributing Guide

## Dev Setup

```bash
git clone https://github.com/vertigo-prime/devise_scim.git
cd devise_scim
bundle install
bundle exec rspec   # should report ~285 examples, 0 failures
```

The gem uses [Combustion](https://github.com/pat/combustion) — there is no separate test Rails app to create or maintain. `Combustion.initialize! :all` in `spec/rails_helper.rb` boots a full Rails environment from `spec/internal/` in-process. SQLite is used for the test database; no setup is needed beyond `bundle install`.

---

## Test Configurations

The gem must work correctly under three distinct configurations. The spec suite exercises all three via `before`/`after` blocks that temporarily reconfigure the gem and reset after each example or context.

**Single-tenant token auth:**

```ruby
DeviseScim.configure do |c|
  c.tenancy    = :single
  c.auth_method = :token
  c.token      = "test-token"
end
```

**Single-tenant OAuth:**

```ruby
DeviseScim.configure do |c|
  c.tenancy    = :single
  c.auth_method = :oauth
end
```

Requires Doorkeeper in the Gemfile. OAuth specs stub or use Doorkeeper's test helpers to issue access tokens.

**Multi-tenant:**

```ruby
DeviseScim.configure do |c|
  c.tenancy = :multi
end
```

Multi-tenant specs create `DeviseScim::ScimTenant` records and pass their tokens via the `Authorization` header.

Always call `DeviseScim.reset_configuration!` in an `after` block (or use the provided RSpec helpers) to avoid leaking configuration between examples.

---

## Running Checks

All three checks must pass before submitting a PR:

```bash
# Run the full test suite
bundle exec rspec

# Lint — fix safe autocorrections first, then review the rest
bundle exec rubocop --autocorrect
bundle exec rubocop

# Static security analysis
bundle exec brakeman --force --no-pager
```

The CI workflow (`.github/workflows/main.yml`) runs all three. A PR with failing Brakeman output will not be merged regardless of test results.

---

## Test App Structure

`spec/internal/` is the Combustion test application. It is a minimal Rails app that exists solely to host the engine during tests.

**Key files:**

- `spec/internal/db/schema.rb` — defines all tables: `users`, `scim_tenants`, `scim_tenant_users`, `scim_groups`. This schema is loaded via `config.before(:suite)` in `spec/rails_helper.rb`, ensuring AR specs see the correct tables even when the generator spec has overwritten the in-memory connection.
- `spec/internal/config/routes.rb` — mounts three `scim_for` variants: the default at `/scim/v2`, a groups-enabled variant at `/scim_groups`, and an OAuth-enabled variant at `/scim_oauth`. The routing spec verifies all three.
- `spec/internal/app/models/user.rb` — the Devise user model used throughout request specs.
- `spec/internal/app/models/scim_group.rb` — the group model used by groups endpoint specs.
- `spec/internal/config/initializers/warden.rb` — patches Devise's `configure_warden!` to be a no-op (Warden middleware is not fully instantiated in the test environment).

> [!WARNING]
> Do not modify `spec/internal/db/schema.rb` without updating all request specs that depend on the table structure. Adding a column that does not exist in production schemas will cause false-positive test passes. Removing a column used by a spec will cause failures that are hard to attribute.

---

## PR Conventions

**Commit messages:**

- Imperative mood, present tense: "Add OAuth token rotation" not "Added OAuth token rotation".
- First line under 72 characters.
- Body explains **why**, not what — the diff shows what changed.
- One logical change per commit; one logical change per PR.

**For SCIM protocol changes:** link to the relevant RFC section in the PR description. RFC 7643 covers the data model; RFC 7644 covers the protocol (endpoints, filter syntax, PATCH operations). Example: "Per RFC 7644 §3.4.2.2, the `pr` operator should match non-null values."

**Test requirements:**

- New features must include request specs in `spec/requests/`.
- Bug fixes must include a regression test that fails before the fix and passes after.
- Filter system changes (new operators, new attribute mappings) need both a `spec/filter/parser_spec.rb` example and a `spec/filter/arel_visitor_spec.rb` example.

---

## Extending the Filter System

The filter pipeline is two files:

**`lib/devise_scim/filter/parser.rb`** — tokenizer + recursive descent AST builder.

- The tokenizer uses explicit `m = regex.match(s)` calls rather than `String#gsub`, because `gsub` clobbers `$&` even with a String pattern argument, which interferes with the match data.
- The AST node types are `Comparison`, `Conjunction`, `Disjunction`, and `AttrPath` (all `Struct`s defined at the top of the file).
- `Parser.parse(str)` is the public entry point. It raises `Filter::Parser::ParseError` (a subclass of `DeviseScim::InvalidFilter`) on syntax errors.

**`lib/devise_scim/filter/arel_visitor.rb`** — maps AST nodes to Arel conditions.

- `SCIM_TO_AR` is the attribute mapping hash. To support a new SCIM attribute, add an entry: `"newScimAttr" => "ar_column_name"`.
- All conditions are built with Arel node methods (`col.eq`, `col.matches`, etc.) — never with string interpolation or `where("column = ?", val)`. This is a hard requirement enforced by Brakeman and code review.
- `ArelVisitor#apply(ast, scope)` returns a new scope with the Arel condition appended via `where`.

**Adding a new operator** (e.g., a hypothetical `contains-all`):

1. Add the operator string to `COMP_OPS` in `parser.rb`.
2. Add a tokenizer branch in the `elsif` chain that emits a `:op` token.
3. Add a `when` branch in `visit_comparison` in `arel_visitor.rb` that returns an Arel condition.
4. Add examples to both spec files.

---

## Adding a New Endpoint

1. **Add route** in `lib/devise_scim/routing.rb` inside the appropriate `draw_*` method, or add a new private method and call it from `scim_for`.

2. **Add controller action** in `app/controllers/devise_scim/`. Inherit from `DeviseScim::ApplicationController` to get `tenant_scope`, `current_scim_tenant`, `render_scim`, and the error rescue chain.

3. **Add request spec** in `spec/requests/`. Test at minimum: unauthenticated request (401), valid request (2xx), and any error paths (404, 409, 400).

4. **Update discovery endpoints** if the new endpoint represents a new resource type or capability:
   - `ServiceProviderConfig` (`app/controllers/devise_scim/service_provider_controller.rb`) — update `supported` flags for filter, sort, etag, etc.
   - `Schemas` (`app/controllers/devise_scim/schemas_controller.rb`) — add a schema entry if introducing a new SCIM resource type.
   - `ResourceTypes` (`app/controllers/devise_scim/resource_types_controller.rb`) — add an entry for the new endpoint.

Discovery endpoint responses are static; update them when the protocol surface changes, not just when implementation details change.

---

## Security

**SQL injection prevention:** all database queries use Arel node methods or parameterized AR queries. The `ArelVisitor` never interpolates user input into strings. The `tenant_scope` helper builds conditions entirely from Arel table/column references. Never introduce `where("#{col} = ?", val)` or equivalent — use `@table[col_name].eq(val)` instead.

**Timing-safe token comparison:** single-tenant Bearer token authentication uses `ActiveSupport::SecurityUtils.secure_compare(raw, config.token)`, which prevents timing-oracle attacks. Do not replace this with `==`.

**BCrypt for token storage:** multi-tenant token digests are stored with `BCrypt::Password.create(raw)`. Do not store raw tokens. Do not use a weaker digest (SHA, MD5) as a "performance optimization".

**Brakeman must stay clean:** run `bundle exec brakeman --force --no-pager` before every PR. A new warning blocks the PR. If you believe a warning is a false positive, add a Brakeman ignore entry with a comment explaining why, and include it in the PR.

**Reporting security issues:** do not open a public GitHub issue for security vulnerabilities. Email the maintainer directly at `devise_scim@vinson.pro`. Include a description of the vulnerability, steps to reproduce, and your assessment of impact. You will receive a response within 72 hours.
