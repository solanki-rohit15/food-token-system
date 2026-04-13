class AddQrToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_column :order_items, :qr_code, :text
    add_column :order_items, :item_code, :string
    add_column :order_items, :redeemed, :boolean
  end
end
