class CreateAbsenceTypes < ActiveRecord::Migration[8.0]
  # Company-scoped leave / absence categories, managed from Settings. Replaces
  # the fixed leave_type enum on leave_requests. `paid` = "counts against the
  # employee's paid-leave (CP) balance".
  def up
    create_table :absence_types, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.boolean :paid, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :absence_types, [ :company_id, :abbreviation ], unique: true

    add_reference :leave_requests, :absence_type, type: :uuid, foreign_key: true, index: true

    # Seed a default set per company and re-point existing leave rows.
    old_by_index = { 0 => "CP", 1 => "CSS", 2 => "MAL", 3 => "MAT", 4 => "EXCEP" }
    defaults = [
      [ "Congé payé", "CP", true ],
      [ "Congé sans solde", "CSS", false ],
      [ "Congé maladie", "MAL", false ],
      [ "Congé maternité", "MAT", false ],
      [ "Récupération", "RECUP", false ],
      [ "Congé exceptionnel", "EXCEP", false ]
    ]

    Company.find_each do |company|
      defaults.each_with_index do |(name, abbr, paid), i|
        execute(<<~SQL.squish)
          INSERT INTO absence_types (id, company_id, name, abbreviation, paid, active, position, created_at, updated_at)
          VALUES (gen_random_uuid(), '#{company.id}', #{quote(name)}, '#{abbr}', #{paid}, true, #{i}, now(), now())
          ON CONFLICT (company_id, abbreviation) DO NOTHING
        SQL
      end
    end

    if column_exists?(:leave_requests, :leave_type)
      old_by_index.each do |idx, abbr|
        execute(<<~SQL.squish)
          UPDATE leave_requests lr
          SET absence_type_id = at.id
          FROM absence_types at
          WHERE at.company_id = lr.company_id AND at.abbreviation = '#{abbr}' AND lr.leave_type = #{idx}
        SQL
      end
      remove_column :leave_requests, :leave_type
    end

    # Anything still unmapped falls back to the company's CP type.
    execute(<<~SQL.squish)
      UPDATE leave_requests lr
      SET absence_type_id = at.id
      FROM absence_types at
      WHERE at.company_id = lr.company_id AND at.abbreviation = 'CP' AND lr.absence_type_id IS NULL
    SQL

    change_column_null :leave_requests, :absence_type_id, false
  end

  def down
    add_column :leave_requests, :leave_type, :integer, null: false, default: 0
    remove_reference :leave_requests, :absence_type
    drop_table :absence_types
  end
end
