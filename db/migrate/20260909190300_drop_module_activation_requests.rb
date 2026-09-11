# Owners no longer pre-order modules — there's nothing to request, every
# feature ships enabled.
class DropModuleActivationRequests < ActiveRecord::Migration[8.0]
  def up
    drop_table :module_activation_requests
  end

  def down
    create_table :module_activation_requests, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :module_key, null: false
      t.integer :status, null: false, default: 0
      t.text :note
      t.uuid :requested_by_id, null: false
      t.uuid :reviewed_by_id
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :module_activation_requests, [ :company_id, :module_key, :status ], name: "index_module_requests_on_company_key_status"
    add_index :module_activation_requests, :company_id
    add_index :module_activation_requests, :requested_by_id
    add_index :module_activation_requests, :reviewed_by_id
  end
end
