class CreateVendorProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_profiles do |t|
      t.references :user,       null: false, foreign_key: true
      t.string     :vendor_id,  null: false
      t.string     :stall_name, null: false
      t.timestamps
    end
    add_index :vendor_profiles, :vendor_id, unique: true
  end
end
