# Per-module pricing is gone — replaced by subscription_prices (one monthly
# price per currency).
class DropPlatformModulePrices < ActiveRecord::Migration[8.0]
  def up
    drop_table :platform_module_prices
  end

  def down
    create_table :platform_module_prices, id: :uuid do |t|
      t.string :key, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "TND"
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :platform_module_prices, [ :key, :currency ], unique: true
  end
end
