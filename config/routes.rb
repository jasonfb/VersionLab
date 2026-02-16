Rails.application.routes.draw do
  devise_for :users
  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
  end

  # Marketing at root
  root to: "marketing/pages#home"

  # Onboarding flow
  scope :start do
    get "/", to: "onboarding#new", as: :onboarding
    post "/check_email", to: "onboarding#check_email", as: :onboarding_check_email
    get "/signup", to: "onboarding#signup", as: :onboarding_signup
    post "/", to: "onboarding#create", as: :onboarding_create
  end

  # API endpoints for React SPA
  namespace :api do
    resources :accounts, only: [:index]
    resources :projects, only: [:index, :create, :update] do
      resources :email_templates, only: [:index, :show, :create, :update, :destroy] do
        resources :sections, controller: "email_template_sections", only: [:index, :create, :destroy] do
          resources :variables, controller: "template_variables", only: [:index, :create, :update, :destroy]
        end
      end
      resources :audiences, only: [:index, :create, :update, :destroy]
    end
    resources :assets, only: [:index, :create, :destroy]
    post "switch_account", to: "accounts#switch"
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # React SPA catch-all (MUST be last)
  get "app",       to: "client_app#index"
  get "app/*path", to: "client_app#index"
end
