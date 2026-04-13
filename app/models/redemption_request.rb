class RedemptionRequest < ApplicationRecord
  belongs_to :token
  belongs_to :vendor, class_name: "User"
   belongs_to :order_item 

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validate :one_pending_per_token, on: :create

  scope :recent, -> { order(created_at: :desc) }

  delegate :user, to: :token, prefix: :employee

  def approve!
    return false unless pending?

    ActiveRecord::Base.transaction do
      token.redeem!(vendor)
      update!(status: :approved, responded_at: Time.current)
    end
    true
  rescue
    false
  end

  def reject!
    return false unless pending?
    update!(status: :rejected, responded_at: Time.current)
    true
  end

  private

  def one_pending_per_token
    if RedemptionRequest.where(token_id: token_id, status: :pending).exists?
      errors.add(:base, "Request already pending")
    end
  end
end