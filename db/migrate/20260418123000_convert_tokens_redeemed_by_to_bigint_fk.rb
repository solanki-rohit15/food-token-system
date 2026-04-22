class ConvertTokensRedeemedByToBigintFk < ActiveRecord::Migration[8.1]
  def up
    rename_column :tokens, :redeemed_by, :redeemed_by_id
    change_column :tokens, :redeemed_by_id, :bigint, using: "redeemed_by_id::bigint"
    add_foreign_key :tokens, :users, column: :redeemed_by_id
    add_index :tokens, :redeemed_by_id
  end

  def down
    remove_index :tokens, :redeemed_by_id if index_exists?(:tokens, :redeemed_by_id)
    remove_foreign_key :tokens, column: :redeemed_by_id
    change_column :tokens, :redeemed_by_id, :integer
    rename_column :tokens, :redeemed_by_id, :redeemed_by
  end
end
