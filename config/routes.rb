Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    post "telemetry", to: "telemetry#create", as: :telemetry
    post "spaces/join", to: "spaces/memberships#create", as: :space_join

    resources :spaces, param: :code, only: :create do
      scope module: :spaces do
        resource :membership, path: "join", only: :create
        resource :state, only: :show
        resource :deck, only: :create
        resources :actions, only: :create
        resource :observer, only: :show
      end
    end

    namespace :archidekt do
      resources :decks, path: "search", only: :index
    end
  end

  mount SolidObjects::Engine => "/solid_objects"

  get "spaces/:space_code", to: "playmats#show", as: :playmat
  root "playmats#show"
end
