# A member with no email should have NULL, not "".
#
# The model left an empty string exactly as the form sent it, and the unique
# index on lower(email) exempts NULL but not "" — so the first member saved
# without an email claimed the "" slot and every one after it failed with a
# duplicate key. The model is fixed; these are the rows it already wrote.
class AMemberWithNoEmailHasNone < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE clients SET email = NULL WHERE email = ''")
    execute("UPDATE users SET email = NULL WHERE email = ''") if column_allows_null?(:users, :email)
  end

  def down
    # Reverting would reintroduce the collision this exists to remove.
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def column_allows_null?(table, column)
    connection.columns(table).find { |c| c.name == column.to_s }&.null
  end
end
