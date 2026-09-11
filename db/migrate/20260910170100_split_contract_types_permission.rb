# Editing the membership-plan catalogue moves off the `contracts` capability
# onto its own `contract_types` one (configuration, not front-desk work).
# Role.seed_defaults_for never touches existing rows, so backfill the
# built-ins: owner gains contract_types, receptionist loses `coaches`.
class SplitContractTypesPermission < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      UPDATE roles SET permissions = array_append(permissions, 'contract_types'), updated_at = now()
      WHERE key = 'owner' AND builtin = TRUE AND NOT ('contract_types' = ANY (permissions))
    SQL
    execute(<<~SQL)
      UPDATE roles SET permissions = array_remove(permissions, 'coaches'), updated_at = now()
      WHERE key = 'receptionist' AND builtin = TRUE
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE roles SET permissions = array_remove(permissions, 'contract_types'), updated_at = now()
      WHERE key = 'owner' AND builtin = TRUE
    SQL
    execute(<<~SQL)
      UPDATE roles SET permissions = array_append(permissions, 'coaches'), updated_at = now()
      WHERE key = 'receptionist' AND builtin = TRUE AND NOT ('coaches' = ANY (permissions))
    SQL
  end
end
