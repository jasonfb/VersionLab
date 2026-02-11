Rails.application.routes.draw do
  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
  end

  # Marketing at root
  root to: "marketing/pages#home"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # React SPA catch-all (MUST be last)
  get "app",       to: "client_app#index"
  get "app/*path", to: "client_app#index"
end
