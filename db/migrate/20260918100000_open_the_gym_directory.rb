# Two things at once, because they are the same decision: a gym is no longer
# reached by a private key handed out in-app, it is found in a public
# directory — and only once its owner has published it.
class OpenTheGymDirectory < ActiveRecord::Migration[8.1]
  def up
    # Null = not published. Nothing is listed until an owner says so, so this
    # migration exposes no existing gym.
    add_column :companies, :listed_at, :datetime
    add_index :companies, :listed_at

    remove_column :companies, :mobile_auth_key
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The pairing keys are gone — restore from a backup instead."
  end
end
