class RedemptionRequest < ApplicationRecord
  belongs_to :token
  belongs_to :vendor, class_name: "User"
  belongs_to :order_item

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validate :one_pending_per_order_item, on: :create
  validate :order_item_belongs_to_token

  scope :recent,  -> { order(created_at: :desc) }
  scope :pending, -> { where(status: :pending) }

  delegate :user, to: :token, prefix: :employee

  # ──────────────────────────────────────────────────────────────────
  # approve! now redeems the specific order_item and its token.
  # ──────────────────────────────────────────────────────────────────
  def approve!
    with_lock do
      return true if approved?
      return false if rejected?

      ActiveRecord::Base.transaction do
        # 1. Redeem the specific order_item (this will also redeem the token)
        order_item.redeem!(vendor)

        # 2. Mark this request as approved
        update!(status: :approved, responded_at: Time.current)
      end
    end

    true
  rescue StandardError => e
    Rails.logger.error("RedemptionRequest#approve! failed: #{e.message}")
    false
  end

  def reject!
    with_lock do
      return true if rejected?
      return false if approved?

      update!(status: :rejected, responded_at: Time.current)
      true
    end
  end

  private

  # Only one pending request per order_item
  def one_pending_per_order_item
    return unless order_item_id.present?
    if RedemptionRequest.where(order_item_id: order_item_id, status: :pending).exists?
      errors.add(:base, "A request is already pending for this item")
    end
  end

  # Ensure the order_item actually belongs to the token
  def order_item_belongs_to_token
    return unless order_item && token
    unless token.order_item_id == order_item_id
      errors.add(:order_item, "does not belong to this token")
    end
  end
end
