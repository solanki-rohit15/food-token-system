Rails.application.routes.draw do
  root to: redirect("/users/sign_in")

  devise_for :users,
    skip: [ :registrations ],
    controllers: {
      sessions:           "users/sessions",
      omniauth_callbacks: "users/omniauth_callbacks",
      passwords:          "devise/passwords"
    }

  # ── Users (password change) ──────────────────────────────────────
  namespace :users do
    get   "change_password", to: "change_passwords#edit",   as: :change_password
    patch "change_password", to: "change_passwords#update"
  end

  # ── Public QR (no auth required) ────────────────────────────────
  # URL embedded in every QR code: GET /qr/:signed_token
  # Behaviour differs by who is logged in (see Public::QrController).
  scope module: :public do
    get "qr/:signed_token", to: "qr#show", as: :public_qr, constraints: { signed_token: /.+/ }
  end

  # ── Employee ─────────────────────────────────────────────────────
  namespace :employee do
    root "dashboard#index"
    resources :food_selections, only: [ :new, :create ]
    post "location", to: "location#update", as: :update_location
    resources :tokens, only: [ :index, :show ] do
      member { get :status }
    end
    resources :redemption_requests, only: [] do
      member do
        post :approve
        post :reject
      end
    end
  end

  # ── Vendor ───────────────────────────────────────────────────────
  namespace :vendor do
    root "dashboard#index"
    get  "scan",        to: "scanner#index",  as: :scan
    post "scan/verify", to: "scanner#verify", as: :verify_scan
    resources :tokens, only: [ :index, :show ] do
      member do
        get :status
        post :send_redemption_request
      end
    end
    resources :employees, only: [ :index, :show ]
  end

  # ── Admin ────────────────────────────────────────────────────────
  namespace :admin do
    root "dashboard#index"
    resources :users do
      member do
        patch :toggle_active
        post  :resend_invitation
      end
    end
    resources :food_items, only: [ :index, :create, :destroy ] do
      member { patch :toggle_active }
    end
    resources :meal_settings, only: [ :index ] do
      collection { patch :update }
    end
    resources :location_settings, only: [ :index ] do
      collection { patch :update }
    end
    resources :tokens, only: [ :index, :show ]
    resources :reports, only: [ :index ] do
      collection do
        get :daily
        get :monthly
        get :employee_wise
        get :export
        get :export_monthly
      end
    end
  end

  # ── ActionCable ──────────────────────────────────────────────────
  mount ActionCable.server => "/cable"

  # ── Health check ─────────────────────────────────────────────────
  get "up" => "rails/health#show", as: :rails_health_check
end
