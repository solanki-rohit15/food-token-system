class AddAdminCreatedToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin_created, :boolean, default: false, null: false

    # Existing non-OAuth users are treated as admin-created accounts.
    execute <<~SQL.squish
      UPDATE users
      SET admin_created = TRUE
      WHERE provider IS NULL OR provider = ''
    SQL
  end

  def down
    remove_column :users, :admin_created
  end
end
