# A gym asking to work with Fitora, before any account exists. Self-service
# gym signup is gone: a salle asks for a demo or a quote, Fitora talks to
# them, and an admin opens the account afterwards. Nothing here belongs to a
# company — that is the whole point, there isn't one yet.
class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.integer :kind, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :contact_name, null: false
      t.string :gym_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :city
      t.string :locale, null: false, default: "fr"
      t.text :message
      # Filled in by whoever handles it, never by the prospect.
      t.text :internal_notes
      t.datetime :handled_at
      t.references :handled_by, type: :uuid, foreign_key: { to_table: :users }
      t.references :company, type: :uuid, foreign_key: true
      t.timestamps
    end

    add_index :leads, [ :status, :created_at ]
    add_index :leads, :email
  end
end
