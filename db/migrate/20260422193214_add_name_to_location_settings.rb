class AddNameToLocationSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :location_settings, :name, :string
  end
end
