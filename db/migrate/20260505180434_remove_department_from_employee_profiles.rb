class RemoveDepartmentFromEmployeeProfiles < ActiveRecord::Migration[8.1]
  def change
    remove_column :employee_profiles, :department, :string
  end
end
