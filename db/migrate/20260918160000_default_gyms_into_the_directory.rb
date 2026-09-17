# Listing is the default for a new gym too. The default belongs to the
# column, not to a model callback: a callback using `||=` cannot tell
# "not given" from "explicitly nil", so it would silently re-list a gym
# that asked to stay out.
class DefaultGymsIntoTheDirectory < ActiveRecord::Migration[8.1]
  def up
    change_column_default :companies, :listed_at, -> { "now()" }
  end

  def down
    change_column_default :companies, :listed_at, nil
  end
end
