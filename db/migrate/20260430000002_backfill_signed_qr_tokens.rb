class BackfillSignedQrTokens < ActiveRecord::Migration[8.1]
  # This migration generates signed_qr_token for all existing OrderItem rows.
  # New rows get their token automatically via the after_create callback in the model.
  # We use update_column to skip model callbacks and validations for speed.
  def up
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest:     "SHA256",
      serializer: JSON
    )

    OrderItem.where(signed_qr_token: nil).find_each do |item|
      token = verifier.generate(
        { item_code: item.item_code, exp: 24.hours.from_now.to_i },
        purpose: :qr_scan
      )
      item.update_column(:signed_qr_token, token)
    end
  end

  def down
    # Reversing would re-expose raw item_codes in QR — intentionally prevented
    raise ActiveRecord::IrreversibleMigration
  end
end
