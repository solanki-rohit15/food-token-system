class Admin::TokensController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_token, only: [:show]

  def index
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    @tokens = Token.for_date(date)
                   .includes(order: [:user, :food_items])
                   .order(created_at: :desc)

    @tokens = @tokens.where(status: params[:status]) if params[:status].present?

    if params[:search].present?
      q = "%#{params[:search]}%"
      @tokens = @tokens.joins(order: :user).where("users.name ILIKE ? OR users.email ILIKE ?", q, q)
    end

    @tokens = @tokens.page(params[:page]).per(25)
    @date   = date
  end

  def show; end

  private

  def set_token
    @token = Token.includes(order: [:user, :food_items]).find(params[:id])
  end

  def ensure_admin!
    redirect_to root_path unless current_user.admin?
  end
end
