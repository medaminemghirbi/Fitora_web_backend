class RemoveSuppliersGedAndHrAdminTables < ActiveRecord::Migration[8.1]
  # Product decision: Fitora drops Suppliers, the generic document library
  # (GED), and the advanced HR admin (employment contracts, leave, payroll)
  # to stay focused on gym day-to-day operations. Pre-launch, no real
  # production data behind these tables — destructive drop is intentional.
  def up
    execute "DELETE FROM notifications WHERE kind = 'document_expiring'"

    drop_table :leave_requests
    drop_table :absence_types
    drop_table :work_contracts
    drop_table :work_contract_types
    drop_table :library_documents
    drop_table :library_folders
    drop_table :suppliers
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Suppliers/GED/HR-admin tables were removed for good — restore from a backup instead."
  end
end
