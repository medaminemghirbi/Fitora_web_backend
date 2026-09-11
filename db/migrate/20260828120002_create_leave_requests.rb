class CreateLeaveRequests < ActiveRecord::Migration[8.0]
  # Leave / absences recorded by the owner directly in an employee's file
  # ("les congés et les demandes remplis par l'admin"). Approved paid leave
  # is what draws down the CP balance (StaffMember#paid_leave_balance).
  def change
    create_table :leave_requests, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :staff_member, type: :uuid, null: false, foreign_key: true, index: true
      t.references :recorded_by, type: :uuid, foreign_key: { to_table: :users }, index: true

      # 0 paid · 1 unpaid · 2 sick · 3 maternity · 4 other
      t.integer :leave_type, null: false, default: 0
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.decimal :days_count, precision: 5, scale: 1, null: false, default: "0.0"

      # 0 pending · 1 approved · 2 rejected — approved by default since the
      # owner enters these directly.
      t.integer :status, null: false, default: 1
      t.string :reason

      t.timestamps
    end

    add_index :leave_requests, [ :staff_member_id, :starts_on ]
  end
end
