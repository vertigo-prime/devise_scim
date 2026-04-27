# frozen_string_literal: true

module DeviseScim
  class ApplicationController < ActionController::API
    before_action :set_content_type

    rescue_from NotFound,      with: :render_not_found
    rescue_from Conflict,      with: :render_conflict
    rescue_from InvalidFilter, with: :render_invalid_filter

    protected

    def current_scim_tenant
      request.env["devise_scim.tenant"]
    end

    def multi_tenant?
      DeviseScim.configuration.tenancy == :multi
    end

    def devise_model
      DeviseScim.configuration.devise_model.constantize
    end

    def tenant_scope
      if multi_tenant? && current_scim_tenant
        stu   = ScimTenantUser.arel_table
        dm    = devise_model.arel_table
        join  = dm.join(stu).on(stu[:user_id].eq(dm[:id])).join_sources
        cond  = stu[tenant_fk_column].eq(current_scim_tenant.id).and(stu[:active].eq(true))
        devise_model.joins(join).where(cond)
      else
        devise_model.all
      end
    end

    # "DeviseScim::ScimTenant" → "scim_tenant_id"; "Org" → "org_id"
    def tenant_fk_column
      "#{DeviseScim.configuration.tenant_model.demodulize.underscore}_id"
    end

    def scim_adapter_for(record, scim_object)
      klass = (DeviseScim.configuration.adapter || "DeviseScim::ScimAdapter").constantize
      klass.new(record, scim_object, tenant: current_scim_tenant)
    end

    def render_scim(obj, status: :ok)
      render body: obj.to_json, status: status, content_type: "application/scim+json"
    end

    private

    def set_content_type
      response.headers["Content-Type"] = "application/scim+json"
    end

    def render_not_found(err)
      render_scim(Scim::Error.not_found(err.message), status: :not_found)
    end

    def render_conflict(err)
      render_scim(Scim::Error.conflict(err.message), status: :conflict)
    end

    def render_invalid_filter(err)
      render_scim(Scim::Error.bad_request(err.message, scim_type: "invalidFilter"), status: :bad_request)
    end
  end
end
