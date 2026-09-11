class CreateWorkContractTypes < ActiveRecord::Migration[8.0]
  # Employment-contract categories (CDI, CDD, SIVP, …) — company-scoped like
  # ContractType (the client "abonnement" plans), and seeded with a standard
  # Tunisian set on company creation. `fixed_term` drives whether a
  # WorkContract of this type needs an end date.
  def change
    create_table :work_contract_types, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.boolean :fixed_term, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :work_contract_types, [ :company_id, :abbreviation ], unique: true
  end
end
