# frozen_string_literal: true

module DeviseScim
  class UsersController < ApplicationController # rubocop:disable Metrics/ClassLength
    def index
      scope = apply_filter(tenant_scope)
      scim_users = scope.map { |u| scim_adapter_for(u, Scim::User.new).to_scim }
      render_scim(Scim::ListResponse.new(resources: scim_users))
    end

    def create
      scim_u = Scim::User.from_h(parsed_body)
      user   = multi_tenant? ? multi_tenant_create(scim_u) : single_tenant_create(scim_u)
      render_scim(scim_adapter_for(user, Scim::User.new).to_scim, status: :created)
    end

    def show
      render_scim(scim_adapter_for(find_user!(params[:id]), Scim::User.new).to_scim)
    end

    def replace
      user   = find_user!(params[:id])
      scim_u = Scim::User.from_h(parsed_body)
      adapter = scim_adapter_for(user, scim_u)
      user.assign_attributes(adapter.attributes_for_update)
      user.save!
      render_scim(scim_adapter_for(user, Scim::User.new).to_scim)
    end

    def update
      user = find_user!(params[:id])
      ops  = Scim::PatchOperation.parse_request(parsed_body)
      apply_patch(user, ops)
      user.save!
      render_scim(scim_adapter_for(user, Scim::User.new).to_scim)
    end

    def destroy
      handle_deprovision(find_user!(params[:id]))
    end

    private

    def parsed_body
      @parsed_body ||= JSON.parse(request.body.read)
    rescue JSON::ParserError
      {}
    end

    def apply_filter(scope)
      return scope unless params[:filter].present?

      ast = Filter::Parser.parse(params[:filter])
      Filter::ArelVisitor.new(devise_model).apply(ast, scope)
    rescue Filter::Parser::ParseError => e
      raise InvalidFilter, e.message
    end

    def find_user!(id)
      user = tenant_scope.find_by("#{devise_model.table_name}.id" => id)
      raise NotFound, "User #{id} not found" unless user

      user
    end

    # ── single-tenant ──────────────────────────────────────────────────────────

    def single_tenant_create(scim_u)
      existing = find_by_uid_or_email(scim_u)

      if existing.nil?
        build_and_save_user(scim_u)
      elsif deprovisioned?(existing)
        reprovision_user(existing, scim_u)
      else
        raise Conflict, "User already exists"
      end
    end

    def build_and_save_user(scim_u)
      user    = devise_model.new
      adapter = scim_adapter_for(user, scim_u)
      user.assign_attributes(adapter.attributes_for_create)
      set_scim_meta(user, scim_u.external_id)
      user.save!
      adapter.after_provision
      user
    end

    def reprovision_user(user, scim_u)
      user.scim_active            = true if col?(:scim_active)
      user.scim_deprovisioned_at  = nil  if col?(:scim_deprovisioned_at)
      user.scim_source            = "scim" if col?(:scim_source)
      adapter = scim_adapter_for(user, scim_u)
      user.assign_attributes(adapter.attributes_for_update)
      user.save!
      adapter.after_provision
      user
    end

    def find_by_uid_or_email(scim_u)
      email = scim_u.user_name || scim_u.primary_email
      uid   = scim_u.external_id

      if uid && col?(:scim_uid)
        devise_model.find_by(scim_uid: uid) || devise_model.find_by(email: email)
      else
        devise_model.find_by(email: email)
      end
    end

    # ── multi-tenant ───────────────────────────────────────────────────────────

    def multi_tenant_create(scim_u)
      email = scim_u.user_name || scim_u.primary_email
      existing = devise_model.find_by(email: email)

      if existing.nil?
        create_and_assign_user(scim_u)
      else
        active_join = tenant_join_for(existing)
        raise Conflict, "User already belongs to this tenant" if active_join

        other_join = other_tenant_join_for(existing)
        if other_join
          handle_exclusivity_conflict(existing, scim_u, other_join)
        else
          claim_user(existing, scim_u)
        end
        existing
      end
    end

    def create_and_assign_user(scim_u)
      user = devise_model.new
      adapter = scim_adapter_for(user, scim_u)
      user.assign_attributes(adapter.attributes_for_create)
      user.scim_source = "scim" if col?(:scim_source)
      user.save!
      assign_to_tenant(user, scim_u.external_id)
      adapter.after_provision
      user
    end

    def claim_user(user, scim_u)
      user.scim_source = "scim" if col?(:scim_source)
      user.save! if user.changed?
      assign_to_tenant(user, scim_u.external_id, claimed_now: true)
      scim_adapter_for(user, scim_u).after_provision
    end

    def handle_exclusivity_conflict(user, scim_u, other_join)
      config = DeviseScim.configuration
      if config.user_exclusivity == :multiple
        assign_to_tenant(user, scim_u.external_id)
        scim_adapter_for(user, scim_u).after_provision
      elsif config.exclusivity_conflict == :reassign
        other_join.update!(active: false)
        assign_to_tenant(user, scim_u.external_id)
        scim_adapter_for(user, scim_u).after_provision
      else
        raise Conflict, "User already belongs to another tenant"
      end
    end

    def tenant_join_for(user)
      ScimTenantUser.find_by("user_id" => user.id,
                             tenant_fk_column => current_scim_tenant.id,
                             "active" => true)
    end

    def other_tenant_join_for(user)
      ScimTenantUser.where("user_id" => user.id, "active" => true)
                    .where.not(tenant_fk_column => current_scim_tenant.id)
                    .first
    end

    def assign_to_tenant(user, external_id, claimed_now: false)
      attrs = {
        "user_id" => user.id,
        tenant_fk_column => current_scim_tenant.id,
        "scim_uid" => external_id,
        "provisioned_at" => Time.current,
        "active" => true
      }
      attrs["scim_claimed_at"] = Time.current if claimed_now
      ScimTenantUser.create!(attrs)
    end

    # ── deprovision ────────────────────────────────────────────────────────────

    def handle_deprovision(user)
      config = DeviseScim.configuration
      source = col?(:scim_source) ? user.scim_source : "scim"

      if source != "scim"
        case config.deprovision_manual_users
        when false
          Rails.logger.warn "[DeviseScim] Skipping deprovision of manual user #{user.id}"
          return render_scim(scim_adapter_for(user, Scim::User.new).to_scim)
        when :error
          raise Conflict, "Cannot deprovision a manually-created user"
        end
      end

      perform_deprovision(user, config)
      head :no_content
    end

    def perform_deprovision(user, config)
      if multi_tenant?
        ScimTenantUser.find_by("user_id" => user.id,
                               tenant_fk_column => current_scim_tenant.id)
                      &.update!(active: false)
      end
      if config.soft_delete
        user.scim_deprovisioned_at = Time.current if col?(:scim_deprovisioned_at)
        user.scim_active           = false if col?(:scim_active)
        user.save! if user.changed?
      end
      scim_adapter_for(user, Scim::User.new).after_deprovision
    end

    # ── patch ──────────────────────────────────────────────────────────────────

    def apply_patch(user, ops)
      ops.each { |op| apply_op(user, op) }
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def apply_op(user, patch_op)
      return apply_valuemap(user, patch_op.value) unless patch_op.raw_path

      case [patch_op.attribute&.downcase, patch_op.sub_attribute&.downcase]
      when ["active", nil]
        user.scim_active = patch_op.value if col?(:scim_active)
      when ["username", nil]
        user.email = patch_op.value
      when ["emails", nil]
        primary = Array(patch_op.value).find { |e| e["primary"] } || Array(patch_op.value).first
        user.email = primary["value"] if primary
      when %w[name givenname]
        user.first_name = patch_op.value if col?(:first_name)
      when %w[name familyname]
        user.last_name = patch_op.value if col?(:last_name)
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def apply_valuemap(user, value)
      return unless value.is_a?(Hash)

      value.each do |key, val|
        case key.downcase
        when "active"   then user.scim_active = val if col?(:scim_active)
        when "username" then user.email = val
        when "name"
          user.first_name = val["givenName"]  if val["givenName"] && col?(:first_name)
          user.last_name  = val["familyName"] if val["familyName"] && col?(:last_name)
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # ── helpers ────────────────────────────────────────────────────────────────

    def set_scim_meta(user, external_id)
      user.scim_uid    = external_id if col?(:scim_uid)
      user.scim_source = "scim"      if col?(:scim_source)
    end

    def col?(name)
      devise_model.column_names.include?(name.to_s)
    end

    def deprovisioned?(user)
      col?(:scim_active) && user.scim_active == false
    end
  end
end
