Rails.application.routes.draw do
  root "pages#home"

  devise_for :users,
    controllers: {
      sessions:           "users/sessions",
      registrations:      "users/registrations",
      omniauth_callbacks: "users/omniauth_callbacks",
      confirmations:      "users/confirmations"
    }

  # ───────── USERS (OTP + PASSWORD) ─────────
  namespace :users do
    get  "otp",          to: "otp#new",                 as: :new_otp
    post "otp/send",     to: "otp#send_otp",            as: :send_otp
    get  "otp/verify",   to: "otp#verify_form",         as: :verify_otp_form
    post "otp/verify",   to: "otp#verify",              as: :verify_otp
    get  "otp/setup",    to: "otp#setup_password_form", as: :setup_password
    post "otp/setup",    to: "otp#setup_password",      as: :save_password

    get   "change_password", to: "change_passwords#edit",   as: :change_password
    patch "change_password", to: "change_passwords#update"
  end

  # ───────── EMPLOYEE ─────────
  namespace :employee do
    root "dashboard#index"

    resources :food_selections, only: [:new, :create]

    resources :tokens, only: [:index, :show] do
      member do
        get :status
      end
    end

    # ✅ CORRECT PLACEMENT (IMPORTANT)
    resources :redemption_requests, only: [] do
      member do
        post :approve
        post :reject
      end
    end
  end

  # ───────── VENDOR ─────────
  namespace :vendor do
    root "dashboard#index"

    get  "scan",        to: "scanner#index",  as: :scan
    post "scan/verify", to: "scanner#verify", as: :verify_scan

    resources :tokens, only: [:index, :show] do
      member do
        post :send_redemption_request
        post :redeem
      end
    end

    resources :employees, only: [:index, :show]
  end

  # ───────── ADMIN ─────────
  namespace :admin do
    root "dashboard#index"

    resources :users do
      member do
        patch :toggle_active
        post  :resend_invitation
      end
    end

    resources :food_items, only: [:index, :create, :destroy] do
      member do
        patch :toggle_active
      end
    end

    resources :meal_settings, only: [:index] do
      collection do
        patch :update
      end
    end

    resources :location_settings, only: [:index] do
      collection do
        patch :update
      end
    end

    resources :tokens, only: [:index, :show]

    resources :reports, only: [:index] do
      collection do
        get :daily
        get :monthly
        get :employee_wise
        get :export
      end
    end
  end

  # ───────── ACTION CABLE ─────────
  mount ActionCable.server => "/cable"

  # ───────── HEALTH CHECK ─────────
  get "up" => "rails/health#show", as: :rails_health_check
end