class RemoveQrCodeFromTokens < ActiveRecord::Migration[8.1]
  def change
    remove_column :tokens, :qr_code, :string
  end
end
