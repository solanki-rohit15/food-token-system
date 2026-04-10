class CreateLocationSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :location_settings do |t|
      t.integer :setting_type, null: false  # 0=ip_based, 1=gps_based
      t.boolean :enabled,      default: false
      t.string  :ip_range
      t.decimal :latitude,     precision: 10, scale: 6
      t.decimal :longitude,    precision: 10, scale: 6
      t.integer :radius_meters, default: 100
      t.timestamps
    end
    add_index :location_settings, :setting_type, unique: true
  end
end
