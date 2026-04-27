# frozen_string_literal: true

require "rails_helper"

# Routes are drawn at boot in spec/internal/config/routes.rb to avoid
# Devise's configure_warden! blowing up on re-draw in test context.
#   - Default prefix (/scim/v2): no groups, no OAuth
#   - /scim_groups: groups enabled
#   - /scim_oauth:  OAuth enabled

def recognize(method, path)
  Rails.application.routes.recognize_path(path, method: method)
rescue ActionController::RoutingError
  nil
end

RSpec.describe "scim_for routing helper" do
  context "User endpoints (default prefix /scim/v2)" do
    it "GET /Users → users#index" do
      expect(recognize(:get, "/scim/v2/Users")).to include(controller: "devise_scim/users", action: "index")
    end

    it "POST /Users → users#create" do
      expect(recognize(:post, "/scim/v2/Users")).to include(controller: "devise_scim/users", action: "create")
    end

    it "GET /Users/:id → users#show" do
      expect(recognize(:get, "/scim/v2/Users/abc-123")).to include(
        controller: "devise_scim/users", action: "show", id: "abc-123"
      )
    end

    it "PUT /Users/:id → users#replace" do
      expect(recognize(:put, "/scim/v2/Users/1")).to include(controller: "devise_scim/users", action: "replace")
    end

    it "PATCH /Users/:id → users#update" do
      expect(recognize(:patch, "/scim/v2/Users/1")).to include(controller: "devise_scim/users", action: "update")
    end

    it "DELETE /Users/:id → users#destroy" do
      expect(recognize(:delete, "/scim/v2/Users/1")).to include(controller: "devise_scim/users", action: "destroy")
    end
  end

  context "Discovery endpoints" do
    it "GET /ServiceProviderConfig → service_provider#show" do
      expect(recognize(:get, "/scim/v2/ServiceProviderConfig"))
        .to include(controller: "devise_scim/service_provider", action: "show")
    end

    it "GET /Schemas → schemas#index" do
      expect(recognize(:get, "/scim/v2/Schemas"))
        .to include(controller: "devise_scim/schemas", action: "index")
    end

    it "GET /ResourceTypes → resource_types#index" do
      expect(recognize(:get, "/scim/v2/ResourceTypes"))
        .to include(controller: "devise_scim/resource_types", action: "index")
    end
  end

  context "Groups disabled by default" do
    it "GET /Groups is not routable at the default prefix" do
      expect(recognize(:get, "/scim/v2/Groups")).to be_nil
    end
  end

  context "Groups enabled (/scim_groups prefix)" do
    it "GET /Groups → groups#index" do
      expect(recognize(:get, "/scim_groups/Groups")).to include(controller: "devise_scim/groups", action: "index")
    end

    it "POST /Groups → groups#create" do
      expect(recognize(:post, "/scim_groups/Groups")).to include(controller: "devise_scim/groups", action: "create")
    end

    it "GET /Groups/:id → groups#show" do
      expect(recognize(:get, "/scim_groups/Groups/1")).to include(controller: "devise_scim/groups", action: "show")
    end

    it "PUT /Groups/:id → groups#replace" do
      expect(recognize(:put, "/scim_groups/Groups/1")).to include(controller: "devise_scim/groups", action: "replace")
    end

    it "PATCH /Groups/:id → groups#update" do
      expect(recognize(:patch, "/scim_groups/Groups/1")).to include(controller: "devise_scim/groups", action: "update")
    end

    it "DELETE /Groups/:id → groups#destroy" do
      expect(recognize(:delete, "/scim_groups/Groups/1")).to include(controller: "devise_scim/groups", action: "destroy")
    end
  end

  context "OAuth disabled by default" do
    it "POST /oauth/token is not routable at the default prefix" do
      expect(recognize(:post, "/scim/v2/oauth/token")).to be_nil
    end
  end

  context "OAuth enabled (/scim_oauth prefix)" do
    it "POST /oauth/token → doorkeeper/tokens#create" do
      expect(recognize(:post, "/scim_oauth/oauth/token"))
        .to include(controller: "doorkeeper/tokens", action: "create")
    end
  end

  context "custom route prefix" do
    it "routes under the custom prefix are routable" do
      expect(recognize(:get, "/scim_groups/Users")).to include(controller: "devise_scim/users", action: "index")
    end

    it "unrecognized paths are not routable" do
      expect(recognize(:get, "/not/a/scim/path")).to be_nil
    end
  end
end
