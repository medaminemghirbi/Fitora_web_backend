class CreatePlatformModulePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_module_prices, id: :uuid do |t|
      # One of ModuleCatalog::KEYS, priced per currency — a company sees
      # each module's price in its own Company#currency (CurrencyCatalog),
      # not one fixed platform currency. A company's monthly total is the
      # sum, in its currency, of the prices of the modules it has enabled.
      # Rows are seeded lazily — PlatformModulePrice.catalog(currency:)
      # find_or_create_by!s one per ModuleCatalog::KEYS the first time that
      # currency is read, copying REFERENCE_CURRENCY's price_cents as a
      # starting point — rather than here at migration time, so neither a
      # newly-catalogued module nor a newly-seen currency needs a manual
      # backfill.
      t.string :key, null: false
      t.integer :price_cents, null: false, default: 0
      t.string :currency, null: false, default: "TND"
      # Whether the module is offered for sale at all — a soft on/off for the
      # catalogue that doesn't touch any company's existing access.
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :platform_module_prices, [ :key, :currency ], unique: true
  end
end
