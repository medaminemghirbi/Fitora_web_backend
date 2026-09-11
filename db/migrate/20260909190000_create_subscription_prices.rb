# The platform's monthly subscription price, one row per currency — a
# Tunisian gym sees it in TND, a European one in EUR. Replaces the
# per-module platform_module_prices now that every feature is included.
class CreateSubscriptionPrices < ActiveRecord::Migration[8.0]
  def change
    create_table :subscription_prices, id: :uuid do |t|
      t.string :currency, null: false
      t.integer :monthly_cents, null: false, default: 0
      t.timestamps
    end
    add_index :subscription_prices, :currency, unique: true
  end
end
