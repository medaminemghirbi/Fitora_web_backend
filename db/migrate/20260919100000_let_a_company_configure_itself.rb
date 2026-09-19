# Fitora has to run a boxing club and an EMS studio off one codebase. Until
# now every difference between them had to be a column, which meant a
# migration per rule and a schema that grew a wart for every business type.
#
# This is the column those rules live in instead. It is read through
# CompanySettings, never as a raw hash: the keys are code, the values are the
# company's. Additive and reversible — nothing reads it yet.
#
# The GIN index is for the platform admin asking "which companies have online
# booking on", not for the hot path: every request that needs settings has
# already loaded the whole company row.
class LetACompanyConfigureItself < ActiveRecord::Migration[8.1]
  def up
    add_column :companies, :settings, :jsonb, null: false, default: {}
    add_index :companies, :settings, using: :gin
  end

  def down
    remove_index :companies, :settings
    remove_column :companies, :settings
  end
end
