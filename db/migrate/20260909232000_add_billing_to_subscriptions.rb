# An owner on the free trial can request activation (payment happens
# off-app); an admin then activates and sets the billing period. Once set,
# `billing_period` is what tells the owner "monthly" vs "yearly" and turns
# `expires_at` into a renewal date rather than a trial deadline.
class AddBillingToSubscriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :subscriptions, :billing_period, :integer
    add_column :subscriptions, :upgrade_requested_at, :datetime
    add_column :subscriptions, :upgrade_requested_period, :string
  end
end
