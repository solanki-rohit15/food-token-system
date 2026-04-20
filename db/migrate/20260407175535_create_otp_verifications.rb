class CreateOtpVerifications < ActiveRecord::Migration[8.1]
   def change
    create_table :otp_verifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string     :otp,        null: false
      t.datetime   :expires_at, null: false
      t.boolean    :verified,   default: false
      t.datetime   :verified_at
      t.timestamps
    end
    add_index :otp_verifications, [:user_id, :verified]
  end
end
