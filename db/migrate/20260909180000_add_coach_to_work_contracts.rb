# A work contract can now be attached either to a staff_member (back-office
# login) or directly to a coach that has no app account — a gym often
# employs trainers it doesn't hand a login to. Exactly one of the two is
# set; see WorkContract validations.
class AddCoachToWorkContracts < ActiveRecord::Migration[8.0]
  def change
    add_reference :work_contracts, :coach, type: :uuid, null: true, foreign_key: true
    change_column_null :work_contracts, :staff_member_id, true
  end
end
