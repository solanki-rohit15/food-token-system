class CreateOrders < ActiveRecord::Migration[8.1]
   def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.date       :date, null: false
      t.timestamps
    end
    add_index :orders, [:user_id, :date], unique: true
    add_index :orders, :date
  end
end
