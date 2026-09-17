class AddActivityToContracts < ActiveRecord::Migration[8.1]
  # Product decision: a Contract now declares exactly which Activity it
  # covers, instead of inheriting an (optional, often unset) scope from its
  # ContractType. This is what lets one generic plan ("3 Mois") be reused to
  # create several activity-specific contracts for the same client — see
  # Contract#usable_for? and Contracts::Create.
  def up
    add_column :contracts, :activity_id, :uuid

    # Backfill: point every existing contract at its company's first active
    # activity. Pre-launch, no real production data behind this column —
    # a best-effort backfill is fine; a genuinely wrong activity is a
    # one-click fix on the client's profile, same as picking the wrong one
    # would be going forward.
    execute <<~SQL
      UPDATE contracts
      SET activity_id = (
        SELECT a.id FROM activities a
        JOIN locations l ON l.id = a.location_id
        WHERE l.company_id = contracts.company_id AND a.active = true
        ORDER BY a.created_at ASC
        LIMIT 1
      )
      WHERE activity_id IS NULL
    SQL

    orphaned = execute("SELECT id FROM contracts WHERE activity_id IS NULL").to_a
    if orphaned.any?
      raise "#{orphaned.size} contract(s) have no activity to backfill to (their company has none configured) — " \
            "add an activity for that company first, or resolve these contracts manually, before re-running this migration."
    end

    change_column_null :contracts, :activity_id, false
    add_foreign_key :contracts, :activities
    add_index :contracts, :activity_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "activity_id backfill is not reversible — restore from a backup instead."
  end
end
