class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :recipient, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.jsonb :data, null: false, default: {}
      t.string :url, null: false
      t.string :subject_type
      t.uuid :subject_id
      # Idempotency key — one notification per (company, dedup_key). Encodes
      # the record + the trigger date so editing an expiry re-notifies.
      t.string :dedup_key, null: false
      t.datetime :read_at
      t.datetime :created_at, null: false
    end

    add_index :notifications, [ :recipient_id, :created_at ]
    add_index :notifications, [ :recipient_id, :read_at ]
    add_index :notifications, [ :subject_type, :subject_id ]
    add_index :notifications, [ :company_id, :dedup_key ], unique: true
  end
end
