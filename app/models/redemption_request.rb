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
  # CRITICAL FIX: approve! now redeems ONLY the specific order_item,
  # NOT the whole token. The token itself only flips to :redeemed when
  # every single order_item under that order has been redeemed.
  # ──────────────────────────────────────────────────────────────────
  def approve!
    return false unless pending?

    ActiveRecord::Base.transaction do
      # 1. Redeem the specific order_item
      order_item.redeem!(vendor)

      # 2. Mark this request as approved
      update!(status: :approved, responded_at: Time.current)

      # 3. If ALL order_items under this token's order are now redeemed,
      #    flip the token status to :redeemed as well.
      check_and_finalize_token!
    end

    true
  rescue StandardError => e
    Rails.logger.error("RedemptionRequest#approve! failed: #{e.message}")
    false
  end

  def reject!
    return false unless pending?
    update!(status: :rejected, responded_at: Time.current)
    true
  end

  private

  # Flip the parent token to :redeemed only when every item is done.
  def check_and_finalize_token!
    order = token.order
    all_items = order.order_items.reload

    if all_items.all?(&:redeemed?)
      token.update!(
        status:      :redeemed,
        redeemed_at: Time.current,
        redeemed_by: vendor.id
      )
    end
  end

  # Only one pending request per order_item (not per token)
  def one_pending_per_order_item
    return unless order_item_id.present?
    if RedemptionRequest.where(order_item_id: order_item_id, status: :pending).exists?
      errors.add(:base, "A request is already pending for this item")
    end
  end

  # Ensure the order_item actually belongs to the token's order
  def order_item_belongs_to_token
    return unless order_item && token
    unless order_item.order_id == token.order_id
      errors.add(:order_item, "does not belong to this token's order")
    end
  end
end
