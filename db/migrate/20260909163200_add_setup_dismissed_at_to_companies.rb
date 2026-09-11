# The owner can dismiss the "Premiers pas" getting-started guide; once set,
# the guide stops showing even if some steps are still incomplete.
class AddSetupDismissedAtToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :setup_dismissed_at, :datetime
  end
end
