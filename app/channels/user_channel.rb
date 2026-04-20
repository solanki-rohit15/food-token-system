class UserChannel < ApplicationCable::Channel
  def subscribed
    # Stream for this specific user — matches broadcast("user_#{id}", ...)
    stream_from "user_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end
