class AddProductionIndexes < ActiveRecord::Migration[8.1]
  def change
    # Speeds up Token expiry queries (expired? checks expires_at + status)
    add_index :tokens, [ :status, :expires_at ],
              name: "index_tokens_on_status_and_expires_at",
              if_not_exists: true

    # Speeds up redeemed_items_count SQL COUNT
    add_index :order_items, :redeemed_at,
              name: "index_order_items_on_redeemed_at",
              if_not_exists: true

    # Speeds up pending redemption checks per order_item
    add_index :redemption_requests, [ :order_item_id, :status ],
              name: "index_redemption_requests_on_order_item_id_and_status",
              if_not_exists: true

    # Speeds up Token.for_date scope (used in dashboard, reports)
    add_index :orders, :date,
              name: "index_orders_on_date",
              if_not_exists: true
  end
end
