class CreateRoles < ActiveRecord::Migration[8.0]
  # Turns the hard-coded StaffMember::CAPABILITIES hash into per-company,
  # editable Role rows. Backfills the four built-in roles for every existing
  # company and links each staff row to the role matching its legacy enum,
  # so nothing changes behaviourally. The legacy staff_members.role integer
  # column is kept for now (dual-read fallback + easy rollback).
  def up
    create_table :roles, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :key, null: false
      t.string :name, null: false
      t.string :permissions, array: true, null: false, default: []
      t.boolean :builtin, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :roles, [ :company_id, :key ], unique: true

    add_reference :staff_members, :role, type: :uuid, foreign_key: true, index: true

    defaults = {
      "owner"        => [ "Propriétaire", %w[clients activities coaches sessions bookings contracts payments reports checkin locations company_library] ],
      "manager"      => [ "Manager",      %w[locations activities coaches sessions bookings clients contracts payments reports checkin company_library] ],
      "receptionist" => [ "Réception",    %w[bookings clients contracts payments checkin reports coaches] ],
      "coach"        => [ "Coach",        %w[checkin] ]
    }
    legacy_enum = { 0 => "manager", 1 => "receptionist", 2 => "coach" }

    say_with_time "seeding built-in roles per company" do
      select_values("SELECT id FROM companies").each do |company_id|
        defaults.each_with_index do |(key, (name, perms)), position|
          array_literal = "ARRAY[#{perms.map { |p| quote(p) }.join(', ')}]::varchar[]"
          execute(<<~SQL.squish)
            INSERT INTO roles (id, company_id, key, name, permissions, builtin, position, created_at, updated_at)
            VALUES (gen_random_uuid(), #{quote(company_id)}, #{quote(key)}, #{quote(name)}, #{array_literal}, true, #{position}, now(), now())
            ON CONFLICT (company_id, key) DO NOTHING
          SQL
        end
      end
    end

    legacy_enum.each do |idx, key|
      execute(<<~SQL.squish)
        UPDATE staff_members sm
        SET role_id = r.id
        FROM roles r
        WHERE r.company_id = sm.company_id AND r.key = #{quote(key)} AND sm.role = #{idx}
      SQL
    end
  end

  def down
    remove_reference :staff_members, :role
    drop_table :roles
  end
end
