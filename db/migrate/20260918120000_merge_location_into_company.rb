# A company has exactly one location, created at signup and never a second
# one, so the site was an abstraction carrying fields Company already had.
# It goes, and Company becomes the place itself.
#
# The join tables that existed only to scope things to a site go with it: a
# coach, a staff member or a plan could never be restricted to "one of the
# sites" when there was only ever one. Multi-site will come back through a
# different mechanism when it is actually needed.
class MergeLocationIntoCompany < ActiveRecord::Migration[8.1]
  REPOINTED = {
    activities: "index_activities_on_company_id",
    sessions: "index_sessions_on_company_id",
    recurring_schedules: "index_recurring_schedules_on_company_id",
    salles: "index_salles_on_company_id"
  }.freeze

  def up
    add_column :companies, :business_hours_start, :time, null: false, default: "06:00:00"
    add_column :companies, :business_hours_end, :time, null: false, default: "22:00:00"

    # Opening hours only ever lived on the site; the rest of its fields are
    # already on Company, so those are only filled in where Company is blank.
    execute <<~SQL
      UPDATE companies c SET
        business_hours_start = l.business_hours_start,
        business_hours_end = l.business_hours_end,
        latitude = COALESCE(c.latitude, l.latitude),
        longitude = COALESCE(c.longitude, l.longitude),
        address = COALESCE(NULLIF(c.address, ''), l.address),
        city = COALESCE(NULLIF(c.city, ''), l.city),
        phone = COALESCE(NULLIF(c.phone, ''), l.phone),
        email = COALESCE(NULLIF(c.email, ''), l.email)
      FROM locations l
      WHERE l.company_id = c.id
    SQL

    REPOINTED.each do |table, index_name|
      # recurring_schedules already carried both — it only needs the site
      # column taken away.
      unless column_exists?(table, :company_id)
        add_column table, :company_id, :uuid
        execute "UPDATE #{table} t SET company_id = l.company_id FROM locations l WHERE l.id = t.location_id"
        change_column_null table, :company_id, false
        add_foreign_key table, :companies
        add_index table, :company_id, name: index_name
      end
      remove_column table, :location_id
    end

    drop_table :coach_locations
    drop_table :staff_member_locations
    drop_table :contract_type_locations
    drop_table :locations
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The site was merged into the company — restore from a backup instead."
  end
end
