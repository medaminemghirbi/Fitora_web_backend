class ContractType < ApplicationRecord
  belongs_to :company

  has_many :contract_type_activities, dependent: :destroy
  has_many :activities, through: :contract_type_activities
  has_many :contracts, dependent: :restrict_with_error

  # Replaces the old free-form duration_days column — an "abonnement" now
  # only ever runs monthly/quarterly/semi_annual/yearly, per product
  # decision. #duration_days below derives the actual day count from this.
  enum :billing_period, { monthly: 0, quarterly: 1, semi_annual: 2, yearly: 3 }

  DURATION_DAYS_BY_PERIOD = { "monthly" => 30, "quarterly" => 90, "semi_annual" => 180, "yearly" => 365 }.freeze

  # Price lives per (plan, activity) on contract_type_activities — see
  # #price_for. The plan itself only carries the cadence and booking rules.
  delegate :currency, to: :company

  validates :name, presence: true
  validates :booking_limit, numericality: { greater_than: 0 }, allow_nil: true
  validates :session_count, numericality: { greater_than: 0 }, allow_nil: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #4f46e5" }

  scope :active, -> { where(active: true) }

  # How long one purchase of this plan lasts — computed from billing_period,
  # used by Contracts::Create/Renew to set expires_at.
  def duration_days
    DURATION_DAYS_BY_PERIOD.fetch(billing_period)
  end

  # What this activity costs under this plan, or nil when the plan isn't
  # sold for it at all.
  def price_for(activity)
    contract_type_activities.find_by(activity_id: activity.id)&.price
  end

  # avoids forcing an owner to enumerate them for a simple all-access plan.
  # Activities are different: a plan is only sold for an activity it has a
  # priced row for, so an activity with no row is not covered.
  def grants_access_to?(activity:)
    contract_type_activities.exists?(activity_id: activity.id)
  end
end
