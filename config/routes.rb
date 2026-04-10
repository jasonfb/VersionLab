Rails.application.routes.draw do
  devise_for :users, skip: [ :registrations ]
  # Admin namespace
  namespace :admin do
    root to: "dashboard#index"
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end

  # Marketing at root
  root to: "marketing/pages#home"
  get "/pricing", to: "marketing/pages#pricing"
  get "/contact", to: "marketing/pages#contact"

  # Onboarding flow
  scope :start do
    get "/", to: "onboarding#new", as: :onboarding
    post "/check_email", to: "onboarding#check_email", as: :onboarding_check_email
    get "/signup", to: "onboarding#signup", as: :onboarding_signup
    post "/", to: "onboarding#create", as: :onboarding_create
  end

  # API endpoints for React SPA
  namespace :api do
    resources :accounts, only: [ :index ]
    resources :account_users, only: [ :index, :create, :update, :destroy ]
    post "upgrade_to_agency", to: "accounts#upgrade_to_agency"
    resources :ai_services, only: [ :index ]
    resources :ai_usage_summaries, only: [ :index ]
    get "lookups", to: "lookups#index"
    resources :clients, only: [ :index, :create, :update ] do
      resources :campaigns, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :summarize
        end
        resources :campaign_documents, only: [ :index, :create, :destroy ]
        resources :campaign_links, only: [ :index, :create, :destroy ]
      end
      resources :client_users, only: [ :index, :create, :destroy ]
      resource :brand_profile, only: [ :show ] do
        post :upsert, on: :collection
      end
      resources :template_imports, only: [ :create ]
      resources :email_templates, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :reset
        end
        resources :sections, controller: "email_template_sections", only: [ :index, :create, :update, :destroy ] do
          resources :variables, controller: "template_variables", only: [ :index, :create, :update, :destroy ]
        end
      end
      resources :audiences, only: [ :index, :show, :create, :update, :destroy ] do
        post :seed, on: :collection
      end
      resources :ads, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :run
          post :reject
          post :resize
          get  :resizes
          get  :results
          get  :download_version
          get  :classifications
          post :confirm_classifications
          post :ai_classify
          post :upload_logo
          delete :remove_logo
        end
        resources :ad_resizes, only: [ :update ], controller: "ad_resizes" do
          member do
            post :rebuild
          end
        end
      end
      resources :emails, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :run
          post :reject
          post :summarize
          get :results
          get :preview
          get :export
        end
        resources :email_documents, only: [ :index, :create, :destroy ]
        resources :autolink_settings, only: [ :index, :update ],
                  controller: "email_autolink_settings",
                  param: :section_id
      end
    end
    resources :assets, only: [ :index, :create, :destroy ]
    resource :subscription, only: [ :show ] do
      post :create_payment_intent
      post :confirm
    end
    resources :payment_methods, only: [ :index, :destroy ] do
      member do
        post :set_default
      end
    end
    resources :payments, only: [ :index ]
    post "switch_account", to: "accounts#switch"
    post "switch_client", to: "accounts#switch_client"
  end

  namespace :admin do
    resources :ai_keys
    resources :users

    resources :accounts do
      resources :account_users
    end
    resources :subscription_tiers
    resources :subscriptions, only: [ :edit, :update ]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # React SPA catch-all (MUST be last)
  get "app",       to: "client_app#index"
  get "app/*path", to: "client_app#index"
end
