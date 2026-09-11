class AddDebtCentsToCompanies < ActiveRecord::Migration[8.0]
  def change
    # What the company currently owes Fitora, tracked by hand by an admin —
    # payment happens outside the app (see PlatformModulePrice), this is just
    # the running balance shown back to the owner on the modules page.
    add_column :companies, :debt_cents, :integer, null: false, default: 0
  end
end
