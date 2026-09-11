class CreateModuleActivationRequests < ActiveRecord::Migration[8.0]
  def change
    # An owner "pre-ordering" a not-yet-enabled module from the marketplace
    # page — a request a Fitora admin reviews and turns into a real
    # mod_<key> flip (Company#set_modules!) rather than the owner ever
    # toggling billing state themselves.
    create_table :module_activation_requests, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string :module_key, null: false
      t.integer :status, null: false, default: 0
      t.text :note
      t.references :requested_by, type: :uuid, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :users }
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :module_activation_requests, [ :company_id, :module_key, :status ], name: "index_module_requests_on_company_key_status"
  end
end
