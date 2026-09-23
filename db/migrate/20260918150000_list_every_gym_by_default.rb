# The directory started empty: a gym only appeared once its owner published
# it, and none ever had. Being in the directory is now the default — an
# active gym is a gym people can find — and the switch in Settings becomes a
# way to step back out rather than a gate to step through.
class ListEveryGymByDefault < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE companies SET listed_at = created_at WHERE listed_at IS NULL"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Unpublishing every gym would hide the ones that chose to be listed."
  end
end
