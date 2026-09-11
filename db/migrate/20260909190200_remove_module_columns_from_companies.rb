# Every feature is now included in the base subscription — no more
# per-company addon toggles.
class RemoveModuleColumnsFromCompanies < ActiveRecord::Migration[8.0]
  def change
    remove_column :companies, :mod_ged, :boolean, default: false, null: false
    remove_column :companies, :mod_payroll, :boolean, default: false, null: false
    remove_column :companies, :mod_suppliers, :boolean, default: false, null: false
  end
end
