class Subscription < ApplicationRecord
  belongs_to :company

  BILLING_PERIODS = { monthly: 0, yearly: 1 }.freeze

  enum :status, { active: 0, inactive: 1, expired: 2, cancelled: 3 }
  # Explicit attribute so the enum resolves even when the dev server's code
  # reloader runs before the schema cache has picked up the new column.
  attribute :billing_period, :integer
  enum :billing_period, BILLING_PERIODS

  validates :starts_at, presence: true
  validates :company_id, uniqueness: true
  validates :upgrade_requested_period, inclusion: { in: BILLING_PERIODS.keys.map(&:to_s) }, allow_nil: true

  # No plans, no tiers — this is just the company's access status with
  # Fitora, set by hand by a platform admin (Api::V1::Admin::CompaniesController#update_subscription).
  # expires_at doubles as the free-trial deadline: set to 14 days out at
  # signup (see Api::V1::CompaniesController#create), and cleared to nil
  # the moment an admin manually grants ongoing access — nil means "not on
  # a ticking clock." Once it passes, or the moment status is anything but
  # active (admin marks it inactive/expired/cancelled),
  # Api::V1::BaseController locks every account in the company except the owner.
  def locked?
    return true unless active?

    expires_at.present? && expires_at <= Time.current
  end

  def days_remaining
    return nil if expires_at.blank?

    [ (expires_at.to_date - Date.current).to_i, 0 ].max
  end

  # True until an admin activates a real (paid) subscription by setting a
  # billing period — everything before that is the free trial.
  def on_trial?
    billing_period.blank?
  end

  # The ones Fitora has to answer. Oldest first: whoever has been waiting
  # longest is the one being kept waiting.
  scope :awaiting_activation, -> { where.not(upgrade_requested_at: nil).order(:upgrade_requested_at) }

  def upgrade_requested?
    upgrade_requested_at.present?
  end

  # The owner asks Fitora to activate their subscription (payment off-app),
  # optionally flagging a preferred billing period for the admin.
  def request_upgrade!(period: nil)
    period = period.to_s if period.present?
    period = nil unless BILLING_PERIODS.key?(period&.to_sym)
    update!(upgrade_requested_at: Time.current, upgrade_requested_period: period)
  end

  def cancel_upgrade_request!
    update!(upgrade_requested_at: nil, upgrade_requested_period: nil)
  end
end
