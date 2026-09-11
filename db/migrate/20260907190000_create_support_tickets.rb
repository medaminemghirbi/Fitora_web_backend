class CreateSupportTickets < ActiveRecord::Migration[8.0]
  def change
    # The "Contact" tab on the owner's modules page — a problem report with
    # optional file/video attachments (Active Storage), reviewed by a
    # Fitora admin across every company from one inbox.
    create_table :support_tickets, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.references :created_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.text :message, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :support_tickets, :status
  end
end
