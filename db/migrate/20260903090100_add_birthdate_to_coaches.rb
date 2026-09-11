class AddBirthdateToCoaches < ActiveRecord::Migration[8.0]
  def change
    add_column :coaches, :birthdate, :date
  end
end
