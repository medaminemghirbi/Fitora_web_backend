class CreateSuppliers < ActiveRecord::Migration[8.0]
  def change
    # Fournisseurs — module "suppliers".
    create_table :suppliers, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category
      t.string :contact_name
      t.string :phone
      t.string :email
      t.text :address
      t.text :notes
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :suppliers, [ :company_id, :name ]
  end
end
