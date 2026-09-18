# A gym signs itself up now (Api::V1::AuthController#register), so the demo
# and quote forms that used to be the only way in are gone, and so is the
# admin inbox that read them. Nothing writes a lead and nothing reads one.
#
# Irreversible, like every other pre-launch migration in this repo.
class DropLeads < ActiveRecord::Migration[8.1]
  def up
    drop_table :leads, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
