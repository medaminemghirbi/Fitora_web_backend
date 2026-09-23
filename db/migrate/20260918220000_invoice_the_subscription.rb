# Access becomes a boolean, and every payment leaves an invoice.
#
# Seven columns and eight derived notions answered one question: does this
# gym have access? The answer is now `subscriptions.active` — read directly,
# never computed. Everything else it used to take to work that out (when the
# trial ended, what was paid for, whether an admin had intervened, whether
# the owner had asked to carry on) is either the invoice history or gone.
#
# An invoice is the record that money arrived: one row per period covered,
# numbered, with the amount frozen at issue. The gym downloads it; "paid
# until" is simply the latest one's period_end.
#
# Irreversible, like every other pre-launch migration in this repo.
class InvoiceTheSubscription < ActiveRecord::Migration[8.1]
  def up
    create_table :invoices, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true
      # Human-facing and unique platform-wide: FIT-2026-0042.
      t.string :number, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false
      # Frozen at issue. A tariff that changes later must never rewrite a
      # past invoice — the same lesson ContractPeriod#base_price taught.
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.integer :billing_period, null: false, default: 0
      t.datetime :issued_at, null: false
      t.references :issued_by, type: :uuid, null: true, foreign_key: { to_table: :users }
      t.string :notes
      t.timestamps
    end

    add_index :invoices, :number, unique: true
    add_index :invoices, [ :company_id, :period_start ]

    add_column :subscriptions, :active, :boolean, null: false, default: true

    # A gym that was open stays open. `status` 0 is the old "active", and
    # a trial still running is still running.
    execute <<~SQL.squish
      UPDATE subscriptions SET active = (
        status = 0
        AND (expires_at IS NULL OR expires_at > NOW())
      )
    SQL

    # An invoice per period already paid for cannot be reconstructed — there
    # was never a record of one. Gyms start with an empty history.
    %i[status expires_at starts_at paid_through upgrade_requested_at upgrade_requested_period]
      .each { |column| remove_column :subscriptions, column, if_exists: true }

    # Arrears are periods without an invoice, times the tariff — a figure
    # that can no longer contradict the history beside it.
    remove_column :companies, :debt_cents, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
