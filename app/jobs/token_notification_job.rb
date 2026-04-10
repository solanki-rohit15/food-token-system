# Stub job — replace with real implementation as needed
class TokenNotificationJob < ApplicationJob
  queue_as :default

  def perform(token_id, event_type = "created")
    token = Token.find_by(id: token_id)
    return unless token

    case event_type
    when "created"
      # Optionally send email notification
      # UserMailer.token_ready(token.user, token).deliver_later
    when "redeemed"
      # Broadcast via ActionCable
      ActionCable.server.broadcast("token_#{token.id}", { event: "redeemed" })
    end
  end
end
