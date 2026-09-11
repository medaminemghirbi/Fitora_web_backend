class CreateWorkContracts < ActiveRecord::Migration[8.0]
  # An employee's employment contract — the source of truth for everything
  # the RH "pré-fiche de paie" needs: contract type & dates, gross salary,
  # hours, recurring allowances, bank/CNSS details, leave entitlement, and
  # notice/termination info. Belongs to a StaffMember (every employee —
  # manager, receptionist, or coach — is one).
  def change
    create_table :work_contracts, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :staff_member, type: :uuid, null: false, foreign_key: true, index: true
      t.references :work_contract_type, type: :uuid, null: false, foreign_key: true, index: true

      t.string :reference
      t.string :job_title
      t.date :starts_on, null: false
      t.date :ends_on
      t.date :trial_period_end

      t.decimal :weekly_hours, precision: 6, scale: 2
      t.decimal :gross_monthly_salary, precision: 12, scale: 3, null: false, default: "0.0"
      t.decimal :hourly_rate, precision: 10, scale: 3
      t.string :currency, null: false, default: "TND"

      # 0 bank_transfer · 1 cash · 2 cheque
      t.integer :payment_method, null: false, default: 0
      t.string :bank_name
      t.string :bank_iban

      t.string :cnss_number
      t.date :cnss_affiliated_on

      # [{ "label" => "Prime transport", "amount" => "50.0" }, …]
      t.jsonb :allowances, null: false, default: []

      t.decimal :paid_leave_days_per_year, precision: 5, scale: 1, null: false, default: "30.0"

      t.integer :notice_period_days
      t.date :terminated_on
      t.string :termination_reason

      # 0 draft · 1 active · 2 ended · 3 terminated
      t.integer :status, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :work_contracts, [ :staff_member_id, :status ]
  end
end
