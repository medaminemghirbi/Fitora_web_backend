# Singleton row of platform-wide knobs a Fitora admin controls. Today just
# the annual-billing discount percentage shown on the owner's subscription
# page; more can be added as columns.
class CreatePlatformSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :platform_settings, id: :uuid do |t|
      t.integer :annual_discount_percent, null: false, default: 10
      t.timestamps
    end
  end
end
