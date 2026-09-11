class CoachLocation < ApplicationRecord
  belongs_to :coach
  belongs_to :location

  validates :coach_id, uniqueness: { scope: :location_id }
  validate :same_company

  private

  def same_company
    return if coach.blank? || location.blank?

    if coach.company_id != location.company_id
      errors.add(:location, "must belong to the coach's company")
    end
  end
end
