# A "salle" is a physical room/hall at the company's location — where
# clients actually work out (weight room, yoga studio, pool...). Distinct
# from Activity (a class TYPE, e.g. "Yoga") and Location (the company's one
# site) — a location has several salles, each shown with photos so the
# member picks a class knowing what the room looks like. Mobile-app facing.
class CreateSalles < ActiveRecord::Migration[8.0]
  def change
    create_table :salles, id: :uuid do |t|
      t.references :location, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :capacity, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
