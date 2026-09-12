Rails.application.routes.draw do
  root "map#show"

  resource :session
  resources :passwords, param: :token

  resources :contributions, only: %i[index new create show]
  resources :places, only: :show, param: :code, constraints: { code: /[^\/]+/ }
  get "styleguide", to: "pages#styleguide"

  get "up" => "rails/health#show", as: :rails_health_check
end
