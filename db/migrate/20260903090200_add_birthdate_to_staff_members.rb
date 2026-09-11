class AddBirthdateToStaffMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :staff_members, :birthdate, :date
  end
end
