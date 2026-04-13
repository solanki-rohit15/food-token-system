class Employee::RedemptionRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_request

  def approve
    if @request.approve!
      ActionCable.server.broadcast("vendor_#{@request.vendor_id}", {
        event: "approved",
        message: "Request approved"
      })
      redirect_back fallback_location: employee_tokens_path, notice: "Approved"
    else
      redirect_back fallback_location: employee_tokens_path, alert: "Failed"
    end
  end

  def reject
    if @request.reject!
      ActionCable.server.broadcast("vendor_#{@request.vendor_id}", {
        event: "rejected",
        message: "Request rejected"
      })
      redirect_back fallback_location: employee_tokens_path, notice: "Rejected"
    else
      redirect_back fallback_location: employee_tokens_path, alert: "Failed"
    end
  end

  private

  def set_request
    @request = RedemptionRequest.find(params[:id])
  end
end