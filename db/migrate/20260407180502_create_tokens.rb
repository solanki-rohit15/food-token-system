class CreateTokens < ActiveRecord::Migration[8.1]
   def change
    create_table :tokens do |t|
      t.references :order,      null: false, foreign_key: true
      t.string     :qr_code,    null: false
      t.integer    :status,     default: 0, null: false  # 0=active, 1=redeemed, 2=expired
      t.datetime   :expires_at, null: false
      t.datetime   :redeemed_at
      t.integer    :redeemed_by  # user_id of vendor
      t.timestamps
    end
    add_index :tokens, :qr_code, unique: true
    add_index :tokens, :status
    add_index :tokens, :expires_at
  end
end
