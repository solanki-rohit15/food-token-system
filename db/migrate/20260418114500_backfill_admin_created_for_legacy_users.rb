class BackfillAdminCreatedForLegacyUsers < ActiveRecord::Migration[8.1]
  def up
    # Legacy records existed before admin_created was introduced.
    # Registrations are disabled in this app, so treat existing records as admin-managed.
    execute <<~SQL.squish
      UPDATE users
      SET admin_created = TRUE
      WHERE admin_created = FALSE
    SQL
  end

  def down
    # no-op: avoid destructive rollback on authorization flag
  end
end
