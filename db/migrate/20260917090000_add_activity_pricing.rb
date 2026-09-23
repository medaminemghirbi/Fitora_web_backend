class AddActivityPricing < ActiveRecord::Migration[8.1]
  # Product decision: each activity carries its own subscription price
  # (Boxe 50/month, Pilates 70/month…) instead of one flat price per plan.
  # The price lives on the existing ContractType×Activity join — a plan is
  # now "a billing cadence + booking rules", and the grid says what each
  # activity costs under it, which keeps the degressive pricing gyms
  # actually use (1 month 250, 3 months 700 — not 750).
  #
  # ContractPeriod gains base_price so a period's price is truly frozen at
  # subscription time: compute_final_price used to re-read the plan on every
  # save, so a catalogue change rewrote past periods' final_price.
  def up
    add_column :contract_type_activities, :price, :decimal, precision: 10, scale: 2

    # Every plan currently has zero join rows, which means "covers every
    # activity" — so give each plan one priced row per activity of its
    # company, at the plan's current price. Behaviour is unchanged and the
    # owner lands on a pre-filled grid to edit.
    execute <<~SQL
      INSERT INTO contract_type_activities (id, contract_type_id, activity_id, price, created_at, updated_at)
      SELECT gen_random_uuid(), ct.id, a.id, ct.price, now(), now()
      FROM contract_types ct
      JOIN locations l ON l.company_id = ct.company_id
      JOIN activities a ON a.location_id = l.id AND a.active = true
      WHERE NOT EXISTS (
        SELECT 1 FROM contract_type_activities cta
        WHERE cta.contract_type_id = ct.id AND cta.activity_id = a.id
      )
    SQL

    # Rows that already existed (access scope, no price) inherit the plan price.
    execute <<~SQL
      UPDATE contract_type_activities cta
      SET price = ct.price
      FROM contract_types ct
      WHERE ct.id = cta.contract_type_id AND cta.price IS NULL
    SQL

    change_column_null :contract_type_activities, :price, false

    add_column :contract_periods, :base_price, :decimal, precision: 10, scale: 2
    # final_price was always plan.price - discount, so the price actually
    # billed is recoverable — no period loses its history here.
    execute "UPDATE contract_periods SET base_price = COALESCE(final_price, 0) + COALESCE(discount, 0) WHERE base_price IS NULL"
    change_column_null :contract_periods, :base_price, false

    # The plan no longer prices anything, and the currency belongs to the
    # company (Company#currency) — both were duplicated sources of truth.
    remove_column :contract_types, :price
    remove_column :contract_types, :currency
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Per-activity pricing replaced the flat plan price — restore from a backup instead."
  end
end
