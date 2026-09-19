# Opening hours, working days and the brand colour become settings.
#
# They were four columns, which is how configuration always starts: one rule,
# one column. The trouble is the next rule, and the one after that — a
# cancellation window, a booking horizon, whether this gym uses rooms — none
# of which deserve a migration each. companies.settings is where those live
# now, and these four belong with them.
#
# The API does not change. The serializer still emits business_hours_start,
# business_hours_end, working_days and primary_color at the top level, and
# the controller still accepts them there; only the storage moved. The
# frontend needs no change, and the settings screens keep working.
#
# Backfills first and verifies before dropping anything. If a single company
# would lose its hours, this raises and the transaction rolls back.
class MoveTheOpeningHoursIntoTheSettings < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL)
      UPDATE companies
      SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
        'hours', jsonb_build_object(
          'start', to_char(business_hours_start, 'HH24:MI'),
          'end',   to_char(business_hours_end,   'HH24:MI'),
          'working_days', to_jsonb(working_days)
        ),
        'branding', jsonb_build_object('primary_color', to_jsonb(primary_color))
      )
    SQL

    missing = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM companies
      WHERE settings #>> '{hours,start}' IS NULL
         OR settings #>> '{hours,end}' IS NULL
         OR settings #> '{hours,working_days}' IS NULL
    SQL

    if missing.positive?
      raise ActiveRecord::IrreversibleMigration,
        "#{missing} company/companies did not take their opening hours into settings. " \
        "Refusing to drop the columns while the data is only in one place."
    end

    remove_column :companies, :business_hours_start
    remove_column :companies, :business_hours_end
    remove_column :companies, :working_days
    remove_column :companies, :primary_color
  end

  def down
    add_column :companies, :business_hours_start, :time, null: false, default: "06:00:00"
    add_column :companies, :business_hours_end, :time, null: false, default: "22:00:00"
    add_column :companies, :working_days, :integer, null: false, default: [ 1, 2, 3, 4, 5 ], array: true
    add_column :companies, :primary_color, :string

    execute(<<~SQL)
      UPDATE companies
      SET business_hours_start = COALESCE(settings #>> '{hours,start}', '06:00')::time,
          business_hours_end   = COALESCE(settings #>> '{hours,end}',   '22:00')::time,
          primary_color        = settings #>> '{branding,primary_color}',
          working_days = COALESCE(
            (SELECT array_agg(value::int ORDER BY value::int)
             FROM jsonb_array_elements_text(settings #> '{hours,working_days}') AS value),
            ARRAY[1, 2, 3, 4, 5]
          )
    SQL
  end
end
