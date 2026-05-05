class AddSignedQrToOrderItems < ActiveRecord::Migration[8.1]
  def change
    # signed_qr_token: a Rails-signed string that replaces raw item_code in QR payload.
    # This is what gets encoded into the QR code SVG — never the raw item_code.
    add_column :order_items, :signed_qr_token, :string
    add_index  :order_items, :signed_qr_token, unique: true
  end
end
