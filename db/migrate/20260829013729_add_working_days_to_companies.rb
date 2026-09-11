class AddWorkingDaysToCompanies < ActiveRecord::Migration[8.0]
  def change
    # Days of the week the company operates, as Date#wday integers
    # (0 = Sunday … 6 = Saturday). Drives the pré-fiche de paie working-day
    # count and the auto business-day count on leave requests. Default is the
    # Tunisian norm Monday–Friday; gyms open on Saturday just add 6.
    add_column :companies, :working_days, :integer, array: true, default: [ 1, 2, 3, 4, 5 ], null: false
  end
end
