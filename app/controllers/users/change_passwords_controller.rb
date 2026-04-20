class Users::ChangePasswordsController < ApplicationController
  skip_before_action :enforce_password_change!
  before_action :authenticate_user!
  layout "auth"

  def edit; end

  def update
    password     = params[:password]&.strip
    confirmation = params[:password_confirmation]&.strip

    if password.blank? || password.length < 8
      flash.now[:alert] = "Password must be at least 8 characters."
      return render :edit, status: :unprocessable_entity
    end

    if password != confirmation
      flash.now[:alert] = "Passwords do not match."
      return render :edit, status: :unprocessable_entity
    end

    if current_user.update(password: password, password_confirmation: confirmation,
                           must_change_password: false)
      # Bypass re-login after password change
      bypass_sign_in(current_user)
      redirect_to current_user.dashboard_path, notice: "Password updated successfully. Welcome!"
    else
      flash.now[:alert] = current_user.errors.full_messages.first
      render :edit, status: :unprocessable_entity
    end
  end
end
