class AddLocaleToCompanies < ActiveRecord::Migration[8.0]
  def up
    add_column :companies, :locale, :string, null: false, default: "fr"

    # Seed each company's language from its owner's personal preference so
    # nothing visibly changes on deploy for existing tenants.
    execute <<~SQL.squish
      UPDATE companies
      SET locale = users.locale
      FROM users
      WHERE users.id = companies.owner_id
        AND users.locale IN ('fr', 'en', 'ar')
    SQL
  end

  def down
    remove_column :companies, :locale
  end
end
