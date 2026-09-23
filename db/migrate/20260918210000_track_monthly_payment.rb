# Access is paid for off-app, month by month. Until now nothing recorded
# whether the current month had actually been paid: a gym stayed unlocked
# until an admin noticed and suspended it by hand.
#
# `paid_through` is the last day the gym has paid for. Everything else is
# derived from it — whether this month is settled, how long is left before
# access closes, and why it closed.
#
# Deliberately a date rather than the "paid this month" boolean it stands
# in for. A boolean has to be flipped back by a scheduled job every month,
# and a month where that job does not run leaves every gym either wrongly
# locked or wrongly free. A date needs nothing to run to stay correct: the
# answer is read against today.
class TrackMonthlyPayment < ActiveRecord::Migration[8.1]
  def up
    add_column :subscriptions, :paid_through, :date

    # Everyone already paying is treated as settled for the month in
    # progress, so this does not lock anyone out the moment it ships.
    execute <<~SQL.squish
      UPDATE subscriptions
      SET paid_through = (date_trunc('month', CURRENT_DATE) + interval '1 month - 1 day')::date
      WHERE billing_period IS NOT NULL AND status = 0
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
