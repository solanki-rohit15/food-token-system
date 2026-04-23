class Employee::RedemptionRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_employee!
  before_action :check_location_access
  before_action :set_request

  # POST /employee/redemption_requests/:id/approve
  def approve
    return if performed?

    if @request.approve!
      # Notify vendor the request was approved
      begin
        ActionCable.server.broadcast("vendor_#{@request.vendor_id}", {
          event:        "approved",
          token_id:     @request.token_id,
          item_code:    @request.order_item.item_code,
          category:     @request.order_item.food_item.category_label,
          employee:     current_user.name,
          all_redeemed: @request.token.reload.fully_redeemed?
        })
      rescue StandardError => e
        Rails.logger.error("[RedemptionApproval] Broadcast failed for request=#{@request.id}: #{e.class} #{e.message}")
      end

      respond_to do |format|
        format.html { redirect_back fallback_location: employee_token_path(@request.token), notice: "#{@request.order_item.food_item.category_label} approved." }
        format.json { render json: { success: true, all_redeemed: @request.token.reload.fully_redeemed? } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: employee_token_path(@request.token), alert: "Could not approve request." }
        format.json { render json: { success: false, message: "Could not approve." }, status: :unprocessable_entity }
      end
    end
  end

  # POST /employee/redemption_requests/:id/reject
  def reject
    return if performed?

    if @request.reject!
      begin
        ActionCable.server.broadcast("vendor_#{@request.vendor_id}", {
          event:     "rejected",
          token_id:  @request.token_id,
          item_code: @request.order_item.item_code,
          category:  @request.order_item.food_item.category_label,
          employee:  current_user.name
        })
      rescue StandardError => e
        Rails.logger.error("[RedemptionReject] Broadcast failed for request=#{@request.id}: #{e.class} #{e.message}")
      end

      respond_to do |format|
        format.html { redirect_back fallback_location: employee_token_path(@request.token), notice: "Request rejected." }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: employee_token_path(@request.token), alert: "Could not reject request." }
        format.json { render json: { success: false }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_request
    # SECURITY: scope to requests that belong to this employee's tokens only
    @request = RedemptionRequest
      .joins(token: :order)
      .where(orders: { user_id: current_user.id })
      .find_by(id: params[:id])

    unless @request
      respond_to do |format|
        format.html { redirect_to employee_tokens_path, alert: "Request not found." }
        format.json { render json: { error: "Not found" }, status: :not_found }
      end
      return
    end
  end

  def ensure_employee!
    redirect_to root_path, alert: "Access denied." unless current_user.employee?
  end
end
