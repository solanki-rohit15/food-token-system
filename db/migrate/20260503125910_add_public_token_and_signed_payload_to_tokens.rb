class AddPublicTokenAndSignedPayloadToTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :tokens, :public_token, :string
    add_column :tokens, :signed_payload, :text
    add_index  :tokens, :public_token, unique: true
  end
end
