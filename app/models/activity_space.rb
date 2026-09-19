# Which rooms an activity is allowed to run in.
#
# Absence means "anywhere": an activity with no rows here is unconstrained.
# Rows exist only where a real restriction does — the reformer studio cannot
# host boxing, so boxing names the rooms it can use and everything else stays
# empty.
class ActivitySpace < ApplicationRecord
  belongs_to :activity
  belongs_to :space

  validates :space_id, uniqueness: { scope: :activity_id }
  validate :same_company

  private

  # An activity and the room it runs in must belong to the same gym.
  # Compared as objects, not ids, so an unsaved record's two nil ids are not
  # read as a match.
  def same_company
    return if activity.blank? || space.blank?

    errors.add(:space, "must belong to the same gym as the activity") if activity.company != space.company
  end
end
