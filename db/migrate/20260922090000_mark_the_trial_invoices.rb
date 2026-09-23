# The free trial was "the first period, given away, recorded like any
# other" — so nothing could tell it apart from a paid month, and a gym on
# its 14 free days was shown as already on the Solo tier. The flag says
# which period was the gift.
class MarkTheTrialInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :trial, :boolean, null: false, default: false

    # Signup has only ever written one kind of zero-amount invoice.
    execute <<~SQL
      UPDATE invoices SET trial = TRUE
      WHERE amount_cents = 0 AND notes LIKE 'Période d''essai%'
    SQL
  end

  def down
    remove_column :invoices, :trial
  end
end
