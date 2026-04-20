class CreateMealSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_settings do |t|
      t.string :meal_type,  null: false
      t.string :start_time, null: false
      t.string :end_time,   null: false
      t.timestamps
    end
    add_index :meal_settings, :meal_type, unique: true
  end
end
