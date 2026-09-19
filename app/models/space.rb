# A room: a Pilates studio, an EMS cabin, a boxing ring, a squash court.
#
# Optional per company (CompanySettings FEATURES[:spaces]). A gym leaves the
# feature off, never names a room, and nothing here applies to it. A studio
# turns it on and gets the one thing a room is actually for: knowing that two
# sessions are not in it at once, enforced by a database exclusion constraint
# on sessions, not by a check someone might forget to write.
#
# `kind` is free text ("studio", "cabine", "ring") and nothing branches on
# it. It exists to label rooms for the person reading a schedule.
#
# `capacity` here is the ROOM's ceiling — how many people fit. It is not the
# session's capacity, which comes from the activity and is snapshotted onto
# each session. A session in a room may seat fewer than the room holds; it
# may not seat more.
class Space < ApplicationRecord
  belongs_to :company

  has_many :sessions, dependent: :nullify
  has_many :activity_spaces, dependent: :destroy
  has_many :activities, through: :activity_spaces

  validates :name, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :search, ->(term) {
    next all if term.blank?

    where("spaces.name ILIKE :t OR spaces.kind ILIKE :t", t: "%#{term.strip}%")
  }

  # Which rooms this activity may run in. No activity_spaces rows at all
  # means the activity is unconstrained — the common case, kept free of
  # bookkeeping, so a studio only records the restrictions that are real.
  def self.available_for(activity)
    allowed = activity.space_ids
    return active if allowed.empty?

    active.where(id: allowed)
  end

  def hosts?(activity)
    activity.space_ids.empty? || activity.space_ids.include?(id)
  end

  # Sessions are nullified rather than destroyed when a room is deleted: a
  # room closing is not a reason to erase the history of what happened in it.
  # An owner deletes a room they stopped using; the past stays readable.
  def deletable?
    sessions.scheduled.upcoming.none?
  end
end
