# frozen_string_literal: true

module DeviseScim
  # Groups controller delegates all model interaction to the host app's ScimAdapter subclass.
  # The gem handles the SCIM protocol layer; the adapter handles group lifecycle.
  class GroupsController < ApplicationController
    def index
      render_scim(Scim::ListResponse.new(resources: []))
    end

    def create
      scim_g  = Scim::Group.from_h(parsed_body)
      adapter = scim_adapter_for(nil, scim_g)
      adapter.handle_group_create
      render_scim(adapter.group_to_scim, status: :created)
    rescue NotImplementedError => e
      render_scim(Scim::Error.server_error(e.message), status: :internal_server_error)
    end

    def show
      scim_g  = build_scim_group_for_id(params[:id])
      adapter = scim_adapter_for(nil, scim_g)
      render_scim(adapter.group_to_scim)
    rescue NotImplementedError => e
      render_scim(Scim::Error.server_error(e.message), status: :internal_server_error)
    end

    def replace
      scim_g  = Scim::Group.from_h(parsed_body)
      adapter = scim_adapter_for(nil, scim_g)
      adapter.handle_group_update
      render_scim(adapter.group_to_scim)
    rescue NotImplementedError => e
      render_scim(Scim::Error.server_error(e.message), status: :internal_server_error)
    end

    def update
      scim_g  = Scim::Group.from_h(parsed_body)
      adapter = scim_adapter_for(nil, scim_g)
      adapter.handle_group_update
      render_scim(adapter.group_to_scim)
    rescue NotImplementedError => e
      render_scim(Scim::Error.server_error(e.message), status: :internal_server_error)
    end

    def destroy
      scim_g  = build_scim_group_for_id(params[:id])
      adapter = scim_adapter_for(nil, scim_g)
      adapter.handle_group_destroy
      head :no_content
    end

    private

    def parsed_body
      @parsed_body ||= JSON.parse(request.body.read)
    rescue JSON::ParserError
      {}
    end

    def build_scim_group_for_id(id)
      g    = Scim::Group.new
      g.id = id
      g
    end
  end
end
