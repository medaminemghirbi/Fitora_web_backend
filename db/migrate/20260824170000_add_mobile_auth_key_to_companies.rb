class AddMobileAuthKeyToCompanies < ActiveRecord::Migration[8.0]
  def up
    add_column :companies, :mobile_auth_key, :string

    # Backfill existing companies before the NOT NULL/unique constraints go
    # on — each gets its own random key, same generator the model uses.
    Company.reset_column_information
    Company.find_each do |company|
      company.update_column(:mobile_auth_key, Company.generate_mobile_auth_key)
    end

    change_column_null :companies, :mobile_auth_key, false
    add_index :companies, :mobile_auth_key, unique: true
  end

  def down
    remove_index :companies, :mobile_auth_key
    remove_column :companies, :mobile_auth_key
  end
end
