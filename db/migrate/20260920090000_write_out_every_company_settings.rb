# Every company's settings column should say what its settings ARE.
#
# The backfill in MoveTheOpeningHoursIntoTheSettings filled in the companies
# that existed at the time. A company created afterwards started on `{}` and
# read its hours from CompanySettings' defaults — correct behaviour, but a
# column that describes nothing, and an audit that cannot tell a company
# using the defaults from one whose hours were lost.
#
# Company now normalises on every save (see Company#normalize_settings);
# this writes out the ones nobody has saved since.
class WriteOutEveryCompanySettings < ActiveRecord::Migration[8.1]
  def up
    Company.reset_column_information

    Company.find_each do |company|
      # `settings` reads through CompanySettings, so this writes back the
      # full declared shape with whatever the company already had on top.
      company.update_column(:settings, company.settings.to_h)
    end
  end

  # Nothing to undo: the previous state was the same values, less explicitly.
  def down
  end
end
