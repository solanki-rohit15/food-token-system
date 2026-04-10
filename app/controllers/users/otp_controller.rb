class Users::OtpController < ApplicationController
  skip_before_action :authenticate_user!
  layout "auth"

  # GET /users/otp
  def new
    @email = params[:email] || session[:otp_email]
  end

  # POST /users/otp/send
  def send_otp
    @email = params[:email]&.downcase&.strip

    if @email.blank?
      flash.now[:alert] = "Please enter your email address."
      render :new, status: :unprocessable_entity and return
    end

    @user = User.find_by(email: @email)

    unless @user
      flash.now[:alert] = "No account found with that email. Please contact admin."
      render :new, status: :unprocessable_entity and return
    end

    unless @user.active?
      flash.now[:alert] = "Your account is inactive. Please contact admin."
      render :new, status: :unprocessable_entity and return
    end

    otp = OtpVerification.generate_for(@user)
    UserMailer.otp_email(@user, otp.otp).deliver_later

    session[:otp_user_id] = @user.id
    session[:otp_email]   = @email

    redirect_to users_verify_otp_form_path,
      notice: "OTP sent to #{@email}. Valid for 10 minutes."
  end

  # GET /users/otp/verify
  def verify_form
    unless session[:otp_user_id]
      redirect_to users_new_otp_path, alert: "Session expired. Please start again." and return
    end
    @email = session[:otp_email]
  end

  # POST /users/otp/verify
  def verify
    user_id = session[:otp_user_id]

    unless user_id
      redirect_to users_new_otp_path, alert: "Session expired. Please start again." and return
    end

    @user     = User.find_by(id: user_id)
    otp_code  = Array(params[:otp]).join.strip

    unless @user
      redirect_to users_new_otp_path, alert: "User not found." and return
    end

    if otp_code.blank?
      flash.now[:alert] = "Please enter the OTP."
      @email = session[:otp_email]
      render :verify_form, status: :unprocessable_entity and return
    end

    latest_otp = @user.otp_verifications.valid.unused.last

    unless latest_otp&.verify!(otp_code)
      flash.now[:alert] = "Invalid or expired OTP. Please try again."
      @email = session[:otp_email]
      render :verify_form, status: :unprocessable_entity and return
    end

    session.delete(:otp_user_id)

    if @user.needs_password_setup?
      session[:setup_user_id] = @user.id
      redirect_to users_setup_password_path,
        notice: "OTP verified! Please set a password to continue."
    else
      sign_in(:user, @user)
      redirect_to @user.dashboard_path, notice: "Logged in successfully!"
    end
  end

  # GET /users/otp/setup
  def setup_password_form
    unless session[:setup_user_id]
      redirect_to users_new_otp_path, alert: "Session expired." and return
    end
    @user = User.find_by(id: session[:setup_user_id])
    redirect_to users_new_otp_path, alert: "User not found." unless @user
  end

  # POST /users/otp/setup
  def setup_password
    user_id = session[:setup_user_id]
    unless user_id
      redirect_to users_new_otp_path, alert: "Session expired." and return
    end

    @user = User.find_by(id: user_id)
    unless @user
      redirect_to users_new_otp_path, alert: "User not found." and return
    end

    password     = params[:password]&.strip
    confirmation = params[:password_confirmation]&.strip

    if password.blank? || password.length < 6
      flash.now[:alert] = "Password must be at least 6 characters."
      render :setup_password_form, status: :unprocessable_entity and return
    end

    if password != confirmation
      flash.now[:alert] = "Passwords do not match."
      render :setup_password_form, status: :unprocessable_entity and return
    end

    if @user.update(password: password, password_confirmation: confirmation, confirmed_at: Time.current)
      session.delete(:setup_user_id)
      sign_in(:user, @user)
      redirect_to @user.dashboard_path, notice: "Password set! Welcome to FoodToken."
    else
      flash.now[:alert] = @user.errors.full_messages.first
      render :setup_password_form, status: :unprocessable_entity
    end
  end
end
