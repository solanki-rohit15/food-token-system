class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :toggle_active, :resend_invitation]

  def index
    @users = User.where.not(role: :admin)
                 .includes(:employee_profile, :vendor_profile)
                 .order(:name)
    @users = @users.where(role: params[:role])                if params[:role].present?
    @users = @users.where(active: params[:active] == "true")  if params[:active].present?
    @users = apply_user_search(@users)                         if params[:search].present?
    @users = @users.page(params[:page]).per(20)
  end

  def show
    @recent_tokens = Token.for_user(@user)
                          .includes(order: :food_items)
                          .order(created_at: :desc)
                          .limit(10)
  end

  def new
    @user = User.new(role: :employee)
  end

def create
  temp_password = Devise.friendly_token[0, 12]

  @user = User.new(user_params.merge(
    password:              temp_password,
    password_confirmation: temp_password,
    confirmed_at:          Time.current,
    admin_created:         true,
    must_change_password:  true
  ))

  if @user.save
    UserMailer.invitation_email(@user, temp_password).deliver_later

    redirect_to admin_users_path,
                notice: "#{@user.name} created. Login credentials sent by email."
  else
    flash.now[:alert] = @user.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end
end

  def edit; end
  
def update
  if @user.update(update_user_params)
    redirect_to admin_users_path, notice: "User updated successfully."
  else
    flash.now[:alert] = @user.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end
end

  def destroy
    if @user == current_user
      render json: { success: false, message: "You cannot delete your own account." }, status: :unprocessable_entity
      return
    end
    name = @user.name
    @user.destroy!
    render json: { success: true, id: @user.id, message: "#{name} has been deleted." }
  end

  def toggle_active
    @user.update!(active: !@user.active?)
    message = "#{@user.name} #{@user.active? ? 'activated' : 'deactivated'}."

    render json: {
      success: true,
      id: @user.id,
      active: @user.active?,
      message: message
    }
  end

  def resend_invitation
    temp_password = Devise.friendly_token[0, 12]
    @user.update!(password: temp_password, password_confirmation: temp_password, must_change_password: true)
    UserMailer.invitation_email(@user, temp_password).deliver_later
    message = "Invitation resent to #{@user.email}."

    render json: { success: true, id: @user.id, message: message }
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def apply_user_search(scope)
    q = "%#{params[:search]}%"
    scope.where("name ILIKE ? OR email ILIKE ?", q, q)
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :phone, :active)
  end

  def update_user_params
    permitted = params.require(:user).permit(:name, :email, :role, :phone, :active,
                                             :password, :password_confirmation)
    permitted.delete(:password)              if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
    permitted
  end
end