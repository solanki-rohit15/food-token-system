class CreateEmployeeProfiles < ActiveRecord::Migration[8.1]
   def change
    create_table :employee_profiles do |t|
      t.references :user,         null: false, foreign_key: true
      t.string     :employee_id,  null: false
      t.string     :department,   null: false
      t.timestamps
    end
    add_index :employee_profiles, :employee_id, unique: true
  end
end
