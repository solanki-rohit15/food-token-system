class ChangeTimeToMealSettings < ActiveRecord::Migration[8.1]
  def up
    change_column :meal_settings, :start_time, :time, using: "start_time::time"
    change_column :meal_settings, :end_time, :time, using: "end_time::time"
  end

  def down
    change_column :meal_settings, :start_time, :string
    change_column :meal_settings, :end_time, :string
  end
end
