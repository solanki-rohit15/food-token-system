class VendorChannel < ApplicationCable::Channel
  def subscribed
    # Only vendors can subscribe to vendor channel
    if current_user.vendor?
      stream_from "vendor_#{current_user.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end
