class RemoveUniqueIndexFromOrdersUserDate < ActiveRecord::Migration[8.0]
  def change
    remove_index :orders, [:user_id, :date], name: "index_orders_on_user_id_and_date", unique: true
    add_index    :orders, [:user_id, :date], name: "index_orders_on_user_id_and_date"
  end
end
