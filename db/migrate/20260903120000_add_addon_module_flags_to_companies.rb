class AddAddonModuleFlagsToCompanies < ActiveRecord::Migration[8.0]
  # One boolean per individually-sold addon module — see
  # ModuleCatalog::ADDON_KEYS for the current, authoritative list.
  # clients/classes/bookings/memberships/billing/hr never get a column
  # here — they're ModuleCatalog::CORE_KEYS, the mandatory bundle every
  # company has with no toggle. Columns this migration originally added
  # and later dropped (mod_client_portal, mod_messaging, mod_appointments,
  # mod_pos, mod_maintenance, mod_analytics, mod_fleet, mod_inventory —
  # sold/toggleable with no feature ever built behind them, or a real
  # feature removed by product decision — and mod_clients/mod_classes/
  # mod_bookings/mod_memberships/mod_billing/mod_hr, folded into the core
  # bundle 2026-09-09) are not added here at all rather than added-then-
  # dropped across several files.
  def change
    # Documents
    add_column :companies, :mod_ged,           :boolean, null: false, default: false

    # RH & paie
    add_column :companies, :mod_payroll,       :boolean, null: false, default: false

    # Ressources & terrain
    add_column :companies, :mod_suppliers,     :boolean, null: false, default: false
  end
end
