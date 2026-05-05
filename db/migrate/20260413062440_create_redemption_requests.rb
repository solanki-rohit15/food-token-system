class CreateRedemptionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :redemption_requests do |t|
      t.references :token,  null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.integer    :status, null: false, default: 0   # 0=pending 1=approved 2=rejected
      t.datetime   :responded_at
      t.timestamps
    end

    add_index :redemption_requests, [ :token_id, :status ]
  end
end
