class CreateLibraryDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :library_documents, id: :uuid do |t|
      t.references :folder, type: :uuid, null: false, foreign_key: { to_table: :library_folders }, index: true
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.string :title, null: false
      t.string :reference_number
      t.date :issued_on
      t.date :expires_on
      t.text :notes
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :library_documents, [ :company_id, :expires_on ]
  end
end
