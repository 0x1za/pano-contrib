Rails.application.routes.draw do
  # Admin-only dashboards (the constraint 404s everyone else): the Avo back
  # office at /avo and the feature-flag dashboard at /flipper.
  constraints AdminConstraint.new do
    mount_avo
    mount Flipper::UI.app(Flipper) => "/flipper", as: :flipper
  end

  root "map#show"

  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  resources :contributions, only: %i[index new create show] do
    resource :vote, only: :create
  end
  resources :places, only: :show, param: :code, constraints: { code: /[^\/]+/ }

  # Moderators: the pending queue and its accept / reject decisions.
  get "review", to: "reviews#index", as: :review
  patch "review/:id", to: "reviews#update", as: :review_decision

  get "about", to: "pages#about"
  get "styleguide", to: "pages#styleguide"

  get "up" => "rails/health#show", as: :rails_health_check
end
