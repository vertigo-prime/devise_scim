# frozen_string_literal: true

module DeviseScim
  class ScimAdapter
    attr_reader :record, :scim_user, :scim_group, :tenant

    def initialize(record, scim_object, tenant: nil)
      @record     = record
      @scim_user  = scim_object if scim_object.is_a?(Scim::User)
      @scim_group = scim_object if scim_object.is_a?(Scim::Group)
      @tenant     = tenant
    end

    def attributes_for_create
      base_user_attributes
    end

    def attributes_for_update
      base_user_attributes
    end

    def after_provision;   end
    def after_deprovision; end

    def handle_group_create;  end
    def handle_group_update;  end
    def handle_group_destroy; end

    def to_scim
      scim            = Scim::User.new
      scim.id         = record.id.to_s
      scim.user_name  = record.email
      scim.active     = resolve_active
      scim.emails     = [Scim::Email.new(value: record.email, type: "work", primary: true)]
      scim.name       = build_name
      scim.meta       = build_meta("User")
      scim
    end

    def group_to_scim
      raise NotImplementedError, "#{self.class}#group_to_scim must be implemented when enable_groups is true"
    end

    private

    def base_user_attributes
      attrs = { email: scim_user.user_name || scim_user.primary_email }
      attrs[:first_name] = scim_user.name&.given_name  if column?(:first_name)
      attrs[:last_name]  = scim_user.name&.family_name if column?(:last_name)
      attrs
    end

    def column?(name)
      record.class.respond_to?(:column_names) &&
        record.class.column_names.include?(name.to_s)
    end

    def resolve_active
      if column?(:scim_active)
        record.scim_active
      elsif column?(:deleted_at)
        record.deleted_at.nil?
      else
        true
      end
    end

    def build_name
      given  = column?(:first_name) ? record.first_name : nil
      family = column?(:last_name)  ? record.last_name  : nil
      return nil unless given || family

      Scim::Name.new(given_name: given, family_name: family)
    end

    def build_meta(resource_type)
      Scim::Meta.new(
        resource_type: resource_type,
        created: record.created_at,
        last_modified: record.updated_at
      )
    end
  end
end
