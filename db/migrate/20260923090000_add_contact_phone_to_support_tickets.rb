# A plan request is a conversation Fitora continues by phone — payment is
# arranged off-app — so it cannot be sent without a number to call back.
# `kind` is what lets the server tell a plan request from any other ticket
# and hold it to that.
class AddContactPhoneToSupportTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :support_tickets, :kind, :integer, null: false, default: 0
    add_column :support_tickets, :contact_phone, :string
  end
end
