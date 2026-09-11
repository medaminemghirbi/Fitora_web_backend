class AddAppUpdatesAndAdminNotifications < ActiveRecord::Migration[8.0]
  def change
    # The admin-authored changelog: what changed in this release, with
    # optional screenshots/screen-recordings. The latest row's `version` is
    # what the owner/admin shells show as the running app version.
    create_table :app_updates, id: :uuid do |t|
      t.string :version, null: false
      t.string :title, null: false
      t.text :description
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.datetime :published_at, null: false

      t.timestamps
    end
    add_index :app_updates, :published_at

    # Notification already fans out to a company's own users (owner/staff);
    # a platform-level event like "an admin published an update" has no
    # company at all, so the column has to allow that.
    change_column_null :notifications, :company_id, true
  end
end
