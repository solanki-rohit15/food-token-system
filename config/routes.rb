Rails.application.routes.draw do
  root "pages#home"

  devise_for :users,
    controllers: {
      sessions:           "users/sessions",
      registrations:      "users/registrations",
      omniauth_callbacks: "users/omniauth_callbacks"
    }

  # OTP routes
  namespace :users do
    get  "otp",          to: "otp#new",                  as: :new_otp
    post "otp/send",     to: "otp#send_otp",             as: :send_otp
    get  "otp/verify",   to: "otp#verify_form",          as: :verify_otp_form
    post "otp/verify",   to: "otp#verify",               as: :verify_otp
    get  "otp/setup",    to: "otp#setup_password_form",  as: :setup_password
    post "otp/setup",    to: "otp#setup_password",       as: :save_password
  end

  namespace :employee do
    root "dashboard#index"
    resources :food_selections, only: [:new, :create]
    resources :tokens, only: [:index, :show] do
      member { post :confirm_redemption }
    end
  end

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

  namespace :admin do
    root "dashboard#index"
    resources :users do
      member do
        patch :toggle_active
        post  :resend_invitation
      end
    end
    resources :food_items do
      member { patch :toggle_active }
    end
    resources :meal_settings, only: [:index] do
      collection { patch :update }
    end
    resources :location_settings, only: [:index] do
      collection { patch :update }
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

  mount ActionCable.server => "/cable"
  get "up" => "rails/health#show", as: :rails_health_check
end
