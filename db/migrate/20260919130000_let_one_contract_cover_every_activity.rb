# A membership that covers "everything" could not be sold.
#
# ContractType has covered several activities for a long time
# (contract_type_activities), but a Contract — one member's subscription to
# one of those plans — was pinned to exactly one activity by a NOT NULL. So
# a gym could define "All-access monthly" and then had to pick, at the point
# of sale, the single activity the member was allowed to use.
#
# Nullable now, and the NULL carries meaning: this contract covers every
# activity its ContractType covers. A contract that names an activity still
# means only that one. Both cases are read through Contract#covers_activity?,
# and every existing row keeps working unchanged.
class LetOneContractCoverEveryActivity < ActiveRecord::Migration[8.1]
  def up
    change_column_null :contracts, :activity_id, true
  end

  def down
    # Reversible only while no contract has actually used the NULL. Say so
    # rather than failing halfway through with a constraint violation.
    if Contract.where(activity_id: nil).exists?
      raise ActiveRecord::IrreversibleMigration,
        "Some contracts now cover every activity on their plan (activity_id IS NULL). " \
        "Rolling back would have to pick one activity for them, which is a business " \
        "decision this migration cannot make."
    end

    change_column_null :contracts, :activity_id, false
  end
end
