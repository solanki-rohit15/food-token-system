class Employee::RedemptionRequestsController < ApplicationController
  before_action :require_employee!
  before_action :check_location_access
  before_action :set_request

  # POST /employee/redemption_requests/:id/approve
  def approve
    return if performed?

    if @request.approve!
      token = @request.token.reload
      all_redeemed = token.fully_redeemed?

      broadcast_to_vendor("approved", all_redeemed: all_redeemed)

      render json: {
        success: true,
        all_redeemed: all_redeemed,
        request_id: @request.id,
        order_item_id: @request.order_item_id,
        message: "#{@request.order_item.food_item.category_label} approved."
      }
    else
      render json: { success: false, message: "Could not approve." }, status: :unprocessable_entity
    end
  end

  # POST /employee/redemption_requests/:id/reject
  def reject
    return if performed?

    if @request.reject!
      broadcast_to_vendor("rejected")

      render json: {
        success: true,
        request_id: @request.id,
        order_item_id: @request.order_item_id,
        message: "Request rejected."
      }
    else
      render json: { success: false, message: "Could not reject." }, status: :unprocessable_entity
    end
  end

  private

  # 🔔 Notify vendor via ActionCable
  def broadcast_to_vendor(event, extra = {})
    return unless @request&.order_item&.food_item

    ActionCable.server.broadcast("vendor_#{@request.vendor_id}", {
      event:     event,
      token_id:  @request.token_id,
      item_code: @request.order_item.item_code,
      category:  @request.order_item.food_item.category_label,
      employee:  current_user.name
    }.merge(extra))

  rescue => e
    Rails.logger.error(
      "[Redemption##{event}] Broadcast failed " \
      "request_id=#{@request&.id} " \
      "error=#{e.class} message=#{e.message}"
    )
  end

  def set_request
    @request = RedemptionRequest
      .joins(token: :order)
      .includes(order_item: :food_item) # ⚡ prevents N+1
      .where(orders: { user_id: current_user.id })
      .find_by(id: params[:id])

    return if @request

    render json: { success: false, message: "Request not found." }, status: :not_found
  end
end
