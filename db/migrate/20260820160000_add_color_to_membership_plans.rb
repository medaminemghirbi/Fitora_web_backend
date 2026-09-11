class AddColorToMembershipPlans < ActiveRecord::Migration[8.0]
  def change
    # Lets an owner tell plans apart at a glance (e.g. the Abonnements table's
    # row accent) without relying on status alone. Indigo default matches the
    # app's own primary color so existing plans don't all render as pure grey.
    add_column :membership_plans, :color, :string, null: false, default: "#4f46e5"
  end
end
