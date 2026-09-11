# AbsenceTypeSerializer, RoleSerializer, WorkContractTypeSerializer, and
# AdminCompanySerializer each call an association's #size/#count per row on
# an index endpoint — an extra COUNT query per listed record (found via a
# Bullet audit). Counter caches turn that into a plain column read; existing
# rows are backfilled in the same migration since these types/roles already
# have real data.
class AddCounterCachesForListSerializers < ActiveRecord::Migration[8.0]
  def up
    add_column :absence_types, :leave_requests_count, :integer, null: false, default: 0
    add_column :roles, :staff_members_count, :integer, null: false, default: 0
    add_column :work_contract_types, :work_contracts_count, :integer, null: false, default: 0
    add_column :companies, :locations_count, :integer, null: false, default: 0

    execute(<<~SQL)
      UPDATE absence_types SET leave_requests_count = (
        SELECT COUNT(*) FROM leave_requests WHERE leave_requests.absence_type_id = absence_types.id
      )
    SQL
    execute(<<~SQL)
      UPDATE roles SET staff_members_count = (
        SELECT COUNT(*) FROM staff_members WHERE staff_members.role_id = roles.id
      )
    SQL
    execute(<<~SQL)
      UPDATE work_contract_types SET work_contracts_count = (
        SELECT COUNT(*) FROM work_contracts WHERE work_contracts.work_contract_type_id = work_contract_types.id
      )
    SQL
    execute(<<~SQL)
      UPDATE companies SET locations_count = (
        SELECT COUNT(*) FROM locations WHERE locations.company_id = companies.id
      )
    SQL
  end

  def down
    remove_column :absence_types, :leave_requests_count
    remove_column :roles, :staff_members_count
    remove_column :work_contract_types, :work_contracts_count
    remove_column :companies, :locations_count
  end
end
