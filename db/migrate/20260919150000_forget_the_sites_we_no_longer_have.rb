# companies.locations_count counted rows in a table that no longer exists.
#
# Location and Salle were deleted when a Company became the venue itself;
# this counter cache outlived them and has had nothing to count since.
# Nothing in the app, the specs or the frontend reads it.
class ForgetTheSitesWeNoLongerHave < ActiveRecord::Migration[8.1]
  def up
    remove_column :companies, :locations_count
  end

  def down
    add_column :companies, :locations_count, :integer, null: false, default: 0
  end
end
