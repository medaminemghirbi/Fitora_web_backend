class AddBrandingToCompanies < ActiveRecord::Migration[8.0]
  def change
    # slug: reserved for future hostname-based tenant resolution
    # (powergym.gerily.tn) — not wired up yet, just the identifier so that
    # can be added later without another migration.
    add_column :companies, :slug, :string
    add_column :companies, :primary_color, :string

    add_index :companies, :slug, unique: true
  end
end
