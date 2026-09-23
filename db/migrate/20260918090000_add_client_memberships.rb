# The person becomes global: one `clients` row per human, identified by email,
# and one `memberships` row per gym they belong to. Before this, a client
# belonged to exactly one company and a login email was unique across the
# platform, so the same person could not exist in two gyms at all.
class AddClientMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :memberships, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :client, type: :uuid, null: false, foreign_key: true
      t.references :company, type: :uuid, null: false, foreign_key: true
      t.boolean :active, null: false, default: true
      t.datetime :joined_at, null: false
      t.text :notes
      t.timestamps
    end
    add_index :memberships, [ :client_id, :company_id ], unique: true

    # Every existing client row is exactly one membership of its company.
    execute <<~SQL
      INSERT INTO memberships (id, client_id, company_id, active, joined_at, notes, created_at, updated_at)
      SELECT gen_random_uuid(), c.id, c.company_id, c.active, c.joined_at, c.notes, now(), now()
      FROM clients c
    SQL

    merge_duplicates_by_email

    remove_column :clients, :company_id
    remove_column :clients, :joined_at
    remove_column :clients, :notes

    # Email now identifies the person, so it is unique across the platform —
    # but a gym can still keep a walk-in with no email at all.
    execute "UPDATE clients SET email = NULL WHERE email IS NOT NULL AND trim(email) = ''"
    add_index :clients, "lower(email)", unique: true, where: "email IS NOT NULL", name: "index_clients_on_lower_email"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Memberships merged duplicate people together — restore from a backup instead."
  end

  private

  # Same email = same person. The oldest row wins, preferring one that already
  # has a login, and every other row's gym data is re-pointed onto it.
  def merge_duplicates_by_email
    execute <<~SQL
      CREATE TEMP TABLE client_merge AS
      SELECT c.id AS dup_id, k.keep_id
      FROM clients c
      JOIN (
        SELECT lower(trim(email)) AS em,
               (ARRAY_AGG(id ORDER BY (password_digest IS NOT NULL) DESC, created_at ASC))[1] AS keep_id
        FROM clients
        WHERE email IS NOT NULL AND trim(email) <> ''
        GROUP BY lower(trim(email))
        HAVING COUNT(*) > 1
      ) k ON lower(trim(c.email)) = k.em
      WHERE c.id <> k.keep_id
    SQL

    # A duplicate that belonged to the SAME gym as the survivor would collide
    # on the one-membership-per-gym index; the survivor's row is the one kept.
    execute <<~SQL
      DELETE FROM memberships m USING client_merge cm
      WHERE m.client_id = cm.dup_id
        AND EXISTS (SELECT 1 FROM memberships k WHERE k.client_id = cm.keep_id AND k.company_id = m.company_id)
    SQL

    # Same for a still-held booking on a session both rows were holding.
    execute <<~SQL
      DELETE FROM bookings b USING client_merge cm
      WHERE b.client_id = cm.dup_id AND b.status = 0
        AND EXISTS (SELECT 1 FROM bookings k WHERE k.client_id = cm.keep_id AND k.session_id = b.session_id AND k.status = 0)
    SQL

    %w[memberships contracts bookings payments].each do |table|
      execute "UPDATE #{table} t SET client_id = cm.keep_id FROM client_merge cm WHERE t.client_id = cm.dup_id"
    end

    execute "DELETE FROM clients WHERE id IN (SELECT dup_id FROM client_merge)"
    execute "DROP TABLE client_merge"
  end
end
