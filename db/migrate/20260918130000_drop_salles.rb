# The rooms table goes: a gym IS the place as far as anyone using Fitora is
# concerned, and nothing was ever scheduled into a room — it was a photo
# gallery with a CRUD screen behind it. Assigning a session to a room is a
# mechanism to design when it is actually needed.
class DropSalles < ActiveRecord::Migration[8.1]
  def up
    # The gallery's images are attachments; dropping the table alone would
    # leave them orphaned in storage.
    execute <<~SQL
      DELETE FROM active_storage_attachments WHERE record_type = 'Salle'
    SQL
    drop_table :salles
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The rooms and their photos are gone — restore from a backup instead."
  end
end
