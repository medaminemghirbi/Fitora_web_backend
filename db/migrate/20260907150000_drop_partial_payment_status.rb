# No more part payments ("avance") — a subscription or a booking is either
# paid in full or unpaid. Renumber the enum to { unpaid: 0, paid: 1 } and
# fold any existing "partial" rows (was 1) back to "unpaid".
class DropPartialPaymentStatus < ActiveRecord::Migration[8.0]
  def up
    %i[contract_periods bookings].each do |table|
      execute "UPDATE #{table} SET payment_status = 0 WHERE payment_status = 1"
      execute "UPDATE #{table} SET payment_status = 1 WHERE payment_status = 2"
    end
  end

  def down
    %i[contract_periods bookings].each do |table|
      execute "UPDATE #{table} SET payment_status = 2 WHERE payment_status = 1"
    end
  end
end
