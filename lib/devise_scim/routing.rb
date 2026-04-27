# frozen_string_literal: true

module DeviseScim
  module Routing
    def scim_for(_resource, at: DeviseScim.configuration.route_prefix)
      config = DeviseScim.configuration
      scope at, format: false do
        draw_user_routes
        draw_group_routes if config.enable_groups
        post "oauth/token", to: "doorkeeper/tokens#create" if config.auth_method == :oauth
        draw_discovery_routes
      end
    end

    private

    def draw_user_routes
      get    "Users",     to: "devise_scim/users#index"
      post   "Users",     to: "devise_scim/users#create"
      get    "Users/:id", to: "devise_scim/users#show"
      put    "Users/:id", to: "devise_scim/users#replace"
      patch  "Users/:id", to: "devise_scim/users#update"
      delete "Users/:id", to: "devise_scim/users#destroy"
    end

    def draw_group_routes
      get    "Groups",     to: "devise_scim/groups#index"
      post   "Groups",     to: "devise_scim/groups#create"
      get    "Groups/:id", to: "devise_scim/groups#show"
      put    "Groups/:id", to: "devise_scim/groups#replace"
      patch  "Groups/:id", to: "devise_scim/groups#update"
      delete "Groups/:id", to: "devise_scim/groups#destroy"
    end

    def draw_discovery_routes
      get "ServiceProviderConfig", to: "devise_scim/service_provider#show"
      get "Schemas",               to: "devise_scim/schemas#index"
      get "ResourceTypes",         to: "devise_scim/resource_types#index"
    end
  end
end

ActionDispatch::Routing::Mapper.include DeviseScim::Routing
