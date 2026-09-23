# Rooms, back — but optional this time.
#
# Location and Salle were deleted when Fitora became gym-only, on the
# reasoning that a gym IS its venue and a second table asking "which room?"
# had one answer. That reasoning holds for a gym and breaks for everyone
# else: a Pilates studio has two studios, an EMS place has four cabins, and
# both need to know which one a session is in and that two sessions are not
# in it at once.
#
# So spaces come back behind a flag (CompanySettings FEATURES[:spaces], off
# by default). A gym never sees the word. A studio turns it on and gets rooms
# with a real double-booking constraint.
#
# `kind` is free text on purpose — "studio", "ring", "cabine", "tatami". An
# enum of room types would be exactly the hardcoded business-type modelling
# this architecture exists to avoid, and nothing branches on it.
class GiveACompanyItsRoomsBack < ActiveRecord::Migration[8.1]
  def change
    create_table :spaces, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string  :name, null: false
      t.string  :kind
      t.integer :capacity
      t.boolean :active, null: false, default: true
      t.jsonb   :settings, null: false, default: {}
      t.timestamps
    end

    add_index :spaces, %i[company_id name], unique: true
    add_index :spaces, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_spaces_on_name_trgm"
    add_check_constraint :spaces, "capacity IS NULL OR capacity > 0", name: "spaces_capacity_positive"

    # Which rooms an activity can run in. NO rows for an activity means "any
    # room" — the common case stays free of bookkeeping, and a studio only
    # records the constraint where one actually exists (the reformer studio
    # can't host boxing).
    create_table :activity_spaces, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :activity, type: :uuid, null: false, foreign_key: true, index: true
      t.references :space, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
    end

    add_index :activity_spaces, %i[activity_id space_id], unique: true
  end
end
