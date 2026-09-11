# `activity_type` (open_access / slot / group_class) was a display-only label
# with no logic anywhere. It becomes `session_format` — how many people a
# session of this activity is for: individual (1) / group (2–9) / collective
# (10+). Enum ordinals change, so remap existing rows.
#
#   old 0 open_access  -> 2 collective
#   old 1 slot         -> 0 individual
#   old 2 group_class  -> 2 collective
class RenameActivityTypeToSessionFormat < ActiveRecord::Migration[8.0]
  def up
    rename_column :activities, :activity_type, :session_format
    change_column_default :activities, :session_format, from: 0, to: 1

    execute(<<~SQL)
      UPDATE activities
      SET session_format = CASE session_format
                             WHEN 1 THEN 0   -- slot        -> individual
                             ELSE 2          -- open_access / group_class -> collective
                           END
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE activities
      SET session_format = CASE session_format
                             WHEN 0 THEN 1   -- individual -> slot
                             ELSE 2          -- group / collective -> group_class
                           END
    SQL

    change_column_default :activities, :session_format, from: 1, to: 0
    rename_column :activities, :session_format, :activity_type
  end
end
