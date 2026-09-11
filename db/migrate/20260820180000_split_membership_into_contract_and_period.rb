class SplitMembershipIntoContractAndPeriod < ActiveRecord::Migration[8.0]
  # A client's ongoing relationship with the gym ("Contract") used to live
  # as one flat `memberships` row per renewal — no link between a client's
  # successive terms on the same plan. This splits that into a `Contract`
  # (client + type, the envelope) that `has_many :contract_periods` (one row
  # per renewal cycle — starts_at/expires_at/status/payment all live here
  # now). "Membership"/"MembershipPlan" become "Contract"/"ContractType" to
  # free up "Membership"/"abonnement" for... nothing anymore, actually — see
  # the companion Subscription migration for why "Contract" was free to
  # reuse here in the first place.
  def up
    rename_table :membership_plans, :contract_types
    rename_table :membership_plan_locations, :contract_type_locations
    rename_column :contract_type_locations, :membership_plan_id, :contract_type_id
    rename_table :membership_plan_activities, :contract_type_activities
    rename_column :contract_type_activities, :membership_plan_id, :contract_type_id

    create_table :contracts, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: true, index: true
      t.references :contract_type, type: :uuid, null: false, foreign_key: true, index: true
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.boolean :auto_renew, default: false, null: false
      t.timestamps
    end

    create_table :contract_periods, id: :uuid do |t|
      t.references :contract, type: :uuid, null: false, foreign_key: true, index: true
      t.integer :status, default: 0, null: false
      t.datetime :starts_at
      t.datetime :expires_at
      t.integer :remaining_bookings
      t.decimal :discount, precision: 10, scale: 2, default: "0.0", null: false
      t.decimal :final_price, precision: 10, scale: 2
      t.integer :payment_status, default: 0, null: false
      t.timestamps
      t.index [ :contract_id, :status ]
    end

    # Group existing memberships by (client, plan, company) into one Contract
    # each, preserving every historical row as a ContractPeriod under it —
    # keeping the period's original id, so bookings/payments referencing the
    # old membership row need only a column rename below, not a value remap.
    groups = execute(<<~SQL)
      SELECT client_id, membership_plan_id, company_id, bool_or(auto_renew) AS auto_renew,
             (array_agg(created_by_id ORDER BY created_at))[1] AS created_by_id
      FROM memberships
      GROUP BY client_id, membership_plan_id, company_id
    SQL

    groups.each do |row|
      created_by_sql = row["created_by_id"] ? "'#{row['created_by_id']}'" : "NULL"
      contract_id = execute(<<~SQL).first["id"]
        INSERT INTO contracts (id, client_id, contract_type_id, company_id, created_by_id, auto_renew, created_at, updated_at)
        VALUES (gen_random_uuid(), '#{row['client_id']}', '#{row['membership_plan_id']}', '#{row['company_id']}',
                #{created_by_sql}, #{row['auto_renew']}, now(), now())
        RETURNING id
      SQL

      execute(<<~SQL)
        INSERT INTO contract_periods (id, contract_id, status, starts_at, expires_at, remaining_bookings, discount, final_price, payment_status, created_at, updated_at)
        SELECT id, '#{contract_id}', status, starts_at, expires_at, remaining_bookings, discount, final_price, payment_status, created_at, updated_at
        FROM memberships
        WHERE client_id = '#{row['client_id']}' AND membership_plan_id = '#{row['membership_plan_id']}' AND company_id = '#{row['company_id']}'
      SQL
    end

    remove_foreign_key :bookings, :memberships
    rename_column :bookings, :membership_id, :contract_period_id
    add_foreign_key :bookings, :contract_periods, column: :contract_period_id

    remove_foreign_key :payments, :memberships
    rename_column :payments, :membership_id, :contract_period_id
    add_foreign_key :payments, :contract_periods, column: :contract_period_id

    drop_table :memberships
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
