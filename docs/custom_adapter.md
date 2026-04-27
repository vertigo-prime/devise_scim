# Custom Adapter Guide

## Overview

`devise_scim` separates protocol concerns from business logic using an adapter pattern. The gem handles all RFC 7643/7644 wire protocol — routing, authentication, filter parsing, serialization, and error responses. Your adapter handles the domain side: what attributes to persist, how to represent a user or group as SCIM JSON, and what side effects to trigger after provisioning events.

Every SCIM operation that touches a record instantiates your adapter and calls one method. You only override the methods relevant to your application.

---

## Generating the adapter

Run the generator to create a pre-filled starting point:

```sh
rails g devise_scim:adapter
```

This creates `app/scim/application_scim_adapter.rb` with every overridable method stubbed out as commented examples.

Then register it in your initializer:

```ruby
# config/initializers/devise_scim.rb
DeviseScim.configure do |config|
  config.adapter = "ApplicationScimAdapter"
end
```

The string is constantized at runtime so the class can be autoloaded normally by Rails.

---

## Adapter lifecycle

The gem instantiates `ScimAdapter.new(record, scim_object, tenant: tenant)` before each operation and calls one method. `record` is the AR user or group instance. `scim_object` is either a `Scim::User` or `Scim::Group` parsed from the request body.

| Operation | Method called | Notes |
|-----------|---------------|-------|
| `POST /Users` (new) | `attributes_for_create` | Attributes are passed to `record.assign_attributes` before `save!` |
| `POST /Users` (re-provision) | `attributes_for_update` + `after_provision` | Called when an inactive SCIM user is re-activated |
| `PUT /Users/:id` | `attributes_for_update` | Full replacement |
| `PATCH /Users/:id` | `attributes_for_update` (per op) | Applied once per SCIM operation |
| `DELETE /Users/:id` | `after_deprovision` | Called after the record is soft-deleted |
| `GET /Users`, `GET /Users/:id` | `to_scim` | Must return a `Scim::User` |
| `POST /Groups` | `handle_group_create` then `group_to_scim` | |
| `PATCH /Groups/:id` | `handle_group_update` then `group_to_scim` | |
| `DELETE /Groups/:id` | `handle_group_destroy` | Returns 204, no body |
| `GET /Groups`, `GET /Groups/:id` | `group_to_scim` | Must return a `Scim::Group` |

`after_provision` is called on **both** initial provisioning and re-provisioning. It is not called on updates.

---

## `attributes_for_create` / `attributes_for_update`

Both methods must return a `Hash` of ActiveRecord attribute names (symbols) to values. The hash is passed to `record.assign_attributes` before `save!` is called.

The base class maps `scim_user.user_name` (or `scim_user.primary_email`) to `email`, and conditionally maps `name.given_name` / `name.family_name` to `first_name` / `last_name` if those columns exist.

Override to add fields:

```ruby
class ApplicationScimAdapter < DeviseScim::ScimAdapter
  def attributes_for_create
    super.merge(
      role:        scim_user.user_type || "member",
      department:  scim_user.name&.formatted,
      phone:       scim_user.phone_numbers&.first&.value
    )
  end

  def attributes_for_update
    super.merge(
      department: scim_user.name&.formatted,
      phone:      scim_user.phone_numbers&.first&.value
    )
    # Don't override role on update — IdPs may not re-send it.
  end
end
```

Use `column?` to guard against attributes that may not exist in every deployment:

```ruby
def attributes_for_create
  attrs = super
  attrs[:role] = scim_user.user_type || "member" if column?(:role)
  attrs
end
```

Access fields from the parsed SCIM payload via `scim_user`:

```ruby
scim_user.user_name          # "alice@example.com"
scim_user.primary_email      # first email with primary: true, falls back to user_name
scim_user.name&.given_name   # "Alice"
scim_user.name&.family_name  # "Smith"
scim_user.name&.formatted    # "Alice Smith" (if IdP sends it)
scim_user.user_type          # "Employee" (Okta enterprise field)
scim_user.phone_numbers&.first&.value
```

---

## `to_scim`

Must return a `Scim::User` instance. The base implementation populates `id`, `user_name`, `active`, `emails`, `name` (if `first_name`/`last_name` columns exist), and `meta`. Override to add custom attributes or change how fields map.

```ruby
def to_scim
  scim            = Scim::User.new
  scim.id         = record.id.to_s
  scim.external_id = record.scim_uid
  scim.user_name  = record.email
  scim.display_name = "#{record.first_name} #{record.last_name}".strip
  scim.active     = resolve_active   # use the private helper — handles scim_active/deleted_at/fallback

  scim.name = Scim::Name.new(
    given_name:  record.first_name,
    family_name: record.last_name,
    formatted:   "#{record.first_name} #{record.last_name}".strip
  )

  scim.emails = [
    Scim::Email.new(value: record.email, type: "work", primary: true)
  ]

  scim.meta = build_meta("User")   # sets resource_type, created, last_modified from record timestamps

  scim
end
```

`Scim::Name`, `Scim::Email`, `Scim::PhoneNumber`, and `Scim::Meta` are keyword-argument structs defined in `DeviseScim::Scim`.

---

## Lifecycle hooks

`after_provision` and `after_deprovision` are called after the record is saved. They have access to `record`, `scim_user`, and `tenant`.

```ruby
def after_provision
  # Send a welcome email the first time the user is provisioned.
  # scim_deprovisioned_at is nil for brand-new users.
  if record.scim_deprovisioned_at.nil?
    UserMailer.welcome(record).deliver_later
  end

  record.update_columns(last_provisioned_at: Time.current)

  AuditLog.create!(
    action:    "scim_provision",
    user_id:   record.id,
    tenant_id: tenant&.id
  )
end

def after_deprovision
  # Revoke active sessions and API keys.
  record.active_tokens.revoke_all!
  record.api_keys.update_all(revoked_at: Time.current)

  AuditLog.create!(
    action:    "scim_deprovision",
    user_id:   record.id,
    tenant_id: tenant&.id
  )
end
```

`@tenant` is the `DeviseScim::ScimTenant` (or your custom tenant model) in multi-tenant mode, and `nil` in single-tenant mode.

---

## Group mapping overview

The gem delegates group operations entirely to the adapter. There is no built-in group model or membership table. You choose the strategy that fits your application:

- **AR model** — a dedicated `Group` model with a join table
- **Rolify** — roles as group membership, no extra table
- **Enum / bitmask** — a column on the user record

Regardless of strategy, you must implement `group_to_scim` (returns `Scim::Group`) and the three `handle_group_*` mutators.

---

## Group operations — AR model approach

```ruby
class ApplicationScimAdapter < DeviseScim::ScimAdapter
  def handle_group_create
    group = Group.find_or_create_by!(scim_group_uid: scim_group.external_id || SecureRandom.uuid) do |g|
      g.display_name = scim_group.display_name
    end
    # Assign initial members if the IdP sends them on create.
    sync_members(group)
  end

  def handle_group_update
    group = Group.find_by!(scim_group_uid: scim_group.external_id || scim_group.id)
    group.update!(display_name: scim_group.display_name)
    sync_members(group)
  end

  def handle_group_destroy
    Group.find_by(scim_group_uid: scim_group.external_id || scim_group.id)&.destroy!
  end

  def group_to_scim
    group = Group.find_by!(scim_group_uid: scim_group.external_id || scim_group.id)

    scim              = Scim::Group.new
    scim.id           = group.id.to_s
    scim.display_name = group.display_name
    scim.meta         = build_meta("Group")
    scim.members      = group.users.map do |u|
      Scim::Member.new(value: u.id.to_s, display: u.email)
    end
    scim
  end

  private

  def sync_members(group)
    incoming_ids = scim_group.members.map(&:value).compact
    return if incoming_ids.empty?

    users = User.where(id: incoming_ids)
    group.users = users
  end
end
```

---

## Group operations — Rolify approach

With Rolify, SCIM groups map to roles. No `Group` model is needed.

```ruby
class ApplicationScimAdapter < DeviseScim::ScimAdapter
  # scim_group.display_name is the role name (e.g. "admin", "billing").

  def handle_group_create
    # Nothing to persist — roles are created on assignment.
  end

  def handle_group_update
    role_name = scim_group.display_name
    incoming  = scim_group.members.map(&:value).compact

    User.with_role(role_name).each do |u|
      u.remove_role(role_name) unless incoming.include?(u.id.to_s)
    end

    User.where(id: incoming).each { |u| u.add_role(role_name) }
  end

  def handle_group_destroy
    # Revoke the role from all users who have it.
    User.with_role(scim_group.display_name).each do |u|
      u.remove_role(scim_group.display_name)
    end
  end

  def group_to_scim
    role_name = scim_group.display_name

    scim              = Scim::Group.new
    scim.id           = Digest::UUID.uuid_v5(Digest::UUID::DNS_NAMESPACE, role_name)
    scim.display_name = role_name
    scim.members      = User.with_role(role_name).map do |u|
      Scim::Member.new(value: u.id.to_s, display: u.email)
    end
    scim
  end
end
```

`scim_group.members` is an array of `Scim::Member` structs with `value` (user id sent by IdP), `display`, and `ref`.

---

## Group operations — enum/flag approach

For applications where group membership is a column on the user record (e.g., a `role` enum):

```ruby
def handle_group_update
  role = scim_group.display_name.downcase  # "admin"
  incoming_ids = scim_group.members.map(&:value).compact

  # Remove role from users no longer in the group.
  User.where(role: role).where.not(id: incoming_ids).update_all(role: "member")

  # Assign role to incoming members.
  User.where(id: incoming_ids).update_all(role: role)
end

def group_to_scim
  role = scim_group.display_name.downcase

  scim              = Scim::Group.new
  scim.id           = scim_group.id
  scim.display_name = scim_group.display_name
  scim.members      = User.where(role: role).map do |u|
    Scim::Member.new(value: u.id.to_s, display: u.email)
  end
  scim
end
```

---

## `ScimGroupIdentifiable` concern

Include `DeviseScim::Concerns::ScimGroupIdentifiable` in your group model to get two class methods for looking up groups by SCIM UID.

```ruby
class Group < ApplicationRecord
  include DeviseScim::Concerns::ScimGroupIdentifiable
  # Requires a `scim_group_uid` string column.
end
```

This adds:

```ruby
Group.find_by_scim_uid(uid, tenant: nil)
# => WHERE scim_group_uid = ? [AND tenant_id = ?]

Group.authenticate_scim_group(scim_group, tenant: nil)
# => find_by_scim_uid(scim_group.external_id || scim_group.id, tenant: tenant)
```

`tenant_id` scoping is applied automatically when the model has a `tenant_id` column and a tenant is passed. Use it inside `group_to_scim` to look up the AR record safely:

```ruby
def group_to_scim
  group = Group.authenticate_scim_group(scim_group, tenant: tenant)
  raise ActiveRecord::RecordNotFound unless group

  scim              = Scim::Group.new
  scim.id           = group.id.to_s
  scim.display_name = group.display_name
  scim.members      = group.users.map { |u| Scim::Member.new(value: u.id.to_s, display: u.email) }
  scim
end
```

---

## Using the tenant context

`@tenant` (accessible as `tenant`) is the authenticated tenant object — a `DeviseScim::ScimTenant` instance in multi-tenant mode, `nil` in single-tenant mode. Use it to scope queries and to attach tenant information to side effects.

```ruby
# Scope a group lookup to the current tenant.
def handle_group_create
  Group.create!(
    display_name:  scim_group.display_name,
    scim_group_uid: scim_group.external_id || SecureRandom.uuid,
    tenant_id:     tenant&.id
  )
end

# Log the tenant name in after_provision.
def after_provision
  Rails.logger.info "[SCIM] Provisioned #{record.email} for tenant=#{tenant&.name || "single"}"
end
```

---

## Full multi-tenant adapter example

```ruby
class ApplicationScimAdapter < DeviseScim::ScimAdapter
  # ── User attributes ──────────────────────────────────────────────────────────

  def attributes_for_create
    super.merge(
      role: scim_user.user_type&.downcase || "member"
    ).tap do |attrs|
      attrs[:department] = scim_user.name&.formatted if column?(:department)
    end
  end

  def after_provision
    AuditEvent.create!(
      tenant_id: tenant.id,
      user_id:   record.id,
      action:    "scim_provision",
      metadata:  { email: record.email, role: record.role }
    )

    # Send welcome email only on initial provisioning.
    UserMailer.welcome(record, tenant: tenant).deliver_later if record.scim_deprovisioned_at.nil?
  end

  def after_deprovision
    record.access_tokens.revoke_all!
    AuditEvent.create!(
      tenant_id: tenant.id,
      user_id:   record.id,
      action:    "scim_deprovision"
    )
  end

  # ── Group operations ─────────────────────────────────────────────────────────

  def handle_group_create
    Group.create!(
      display_name:   scim_group.display_name,
      scim_group_uid: scim_group.external_id || SecureRandom.uuid,
      tenant_id:      tenant.id
    )
  end

  def handle_group_update
    group = Group.find_by_scim_uid(scim_group.external_id || scim_group.id, tenant: tenant)
    group.update!(display_name: scim_group.display_name)
    sync_members(group)
  end

  def handle_group_destroy
    Group.find_by_scim_uid(scim_group.external_id || scim_group.id, tenant: tenant)&.destroy!
  end

  def group_to_scim
    group = Group.find_by_scim_uid(scim_group.external_id || scim_group.id, tenant: tenant)
    raise ActiveRecord::RecordNotFound unless group

    scim              = Scim::Group.new
    scim.id           = group.id.to_s
    scim.display_name = group.display_name
    scim.meta         = build_meta("Group")
    scim.members      = group.users.where(tenant_id: tenant.id).map do |u|
      Scim::Member.new(value: u.id.to_s, display: u.email)
    end
    scim
  end

  private

  def sync_members(group)
    incoming = scim_group.members.map(&:value).compact
    return if incoming.empty?

    group.users = User.where(id: incoming, tenant_id: tenant.id)
  end
end
```
