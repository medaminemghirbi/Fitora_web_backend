class CreateLibraryFolders < ActiveRecord::Migration[8.0]
  def change
    create_table :library_folders, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.string :name, null: false
      t.timestamps
    end

    add_index :library_folders, [ :company_id, :name ], unique: true
  end
end
