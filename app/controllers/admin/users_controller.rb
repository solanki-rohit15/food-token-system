class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :toggle_active, :resend_invitation]

  def index
    @users = User.where.not(role: :admin)
                 .includes(:employee_profile, :vendor_profile)
                 .order(:name)

    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where(active: params[:active] == "true") if params[:active].present?

    if params[:search].present?
      q = "%#{params[:search]}%"
      @users = @users.where("name ILIKE ? OR email ILIKE ?", q, q)
    end

    @users = @users.page(params[:page]).per(20)
  end

  def show
    @recent_tokens = Token.for_user(@user).includes(order: :food_items)
                          .order(created_at: :desc).limit(10)
  end

  def new
    @user = User.new(role: :employee)
  end

  def create
    @user = User.new(user_params)
    @user.confirmed_at = Time.current

    if @user.save
      UserMailer.invitation_email(@user).deliver_later
      redirect_to admin_users_path, notice: "User #{@user.name} created and invited."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @user.update(user_params.except(:password, :password_confirmation)
                               .merge(update_password_params))
      redirect_to admin_user_path(@user), notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "User removed."
  end

  def toggle_active
    @user.update!(active: !@user.active?)
    status = @user.active? ? "activated" : "deactivated"
    redirect_back fallback_location: admin_users_path, notice: "#{@user.name} #{status}."
  end

  def resend_invitation
    UserMailer.invitation_email(@user).deliver_later
    redirect_back fallback_location: admin_user_path(@user), notice: "Invitation resent to #{@user.email}."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :phone, :password, :password_confirmation, :active)
  end

  def update_password_params
    return {} if params.dig(:user, :password).blank?
    { password: params[:user][:password], password_confirmation: params[:user][:password_confirmation] }
  end

  def ensure_admin!
    redirect_to root_path, alert: "Access denied." unless current_user.admin?
  end
end
