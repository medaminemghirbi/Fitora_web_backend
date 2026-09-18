class Company < ApplicationRecord
  # Same allowlist/ceiling as HasPhoto — logo is the one has_one_attached in
  # the app that predates that concern and had no validation at all.
  # content_type below is Marcel-sniffed by Active Storage, not the
  # client-declared header, so a renamed .html/.svg can't pass as an image.
  ALLOWED_LOGO_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_LOGO_SIZE = 10.megabytes

  # The company's display language — one setting for the whole tenant, set by
  # a Fitora admin (Api::V1::Admin::CompaniesController#update_settings). The
  # frontend applies it from the bootstrap payload; there is no per-user
  # language switch inside a company's app.
  LOCALES = %w[fr en ar].freeze

  belongs_to :owner, class_name: "User", inverse_of: :companies

  # White-label branding — logo shown in the owner/coach shells, primary_color
  # overrides --color-primary (see BrandingService on the frontend, which
  # derives hover/soft tones from it via CSS color-mix() rather than storing
  # them separately). slug is unused today; it's reserved so hostname-based
  # tenant resolution can be added later without another migration.
  has_one_attached :logo

  validate :logo_is_an_image
  validate :logo_is_not_too_large

  has_many :coaches, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :recurring_schedules, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :clients, through: :memberships
  has_many :contract_types, dependent: :destroy
  has_many :contracts, dependent: :destroy
  has_many :contract_periods, through: :contracts
  has_many :payments, dependent: :destroy
  has_many :staff_members, dependent: :destroy
  has_many :roles, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :support_tickets, dependent: :destroy

  validates :name, presence: true
  validates :timezone, presence: true
  validates :currency, presence: true, inclusion: { in: CurrencyCatalog::CODES }
  validates :locale, presence: true, inclusion: { in: LOCALES }
  # Date#wday values (0 = Sunday … 6 = Saturday). At least one day, no dupes.
  validates :working_days, presence: true
  validate :working_days_are_valid_weekdays
  validates :slug, uniqueness: true, allow_nil: true,
                    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must contain only lowercase letters, numbers, and hyphens" }
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a hex color like #4f46e5" }, allow_nil: true
  validates :debt_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Admin company search — name / city, plus the owner's name and email.
  scope :search, ->(term) {
    next all if term.blank?

    t = "%#{term.strip}%"
    left_joins(:owner).where(
      "companies.name ILIKE :t OR companies.city ILIKE :t OR " \
      "users.first_name ILIKE :t OR users.last_name ILIKE :t OR users.email ILIKE :t",
      t: t
    ).distinct
  }

  before_validation :normalize_working_days

  # The short symbol shown next to amounts across the app (e.g. "DT", "€").
  def currency_symbol
    CurrencyCatalog.symbol(currency)
  end

  # "Premiers pas" getting-started checklist — the foundational things an
  # owner sets up before running the gym day-to-day. Each flag is derived
  # from data, so completing a step anywhere in the app ticks it off.
  # `dismissed` hides the guide regardless; `complete` is all steps done.
  def setup_state
    steps = {
      activity: activities.exists?,
      contract_type: contract_types.exists?,
      coach: coaches.exists?
    }
    steps.merge(dismissed: setup_dismissed_at.present?, complete: steps.values.all?)
  end

  # Every company has every feature — the whole product is included. Kept
  # as a method (rather than inlining ModuleCatalog::KEYS everywhere)
  # because the bootstrap payload, serializers and Permissions::Resolve all
  # read "which features does this company have" through here.
  def enabled_module_keys
    [ ModuleCatalog::BASE_KEY ] + ModuleCatalog::KEYS
  end

  # The company's monthly subscription price, in its own currency — what
  # its owner's current company-limit tier costs per month. Priced per
  # OWNER (the tier governs how many companies they may run), not per
  # company, so every company under one owner shows the same price.
  def monthly_subscription_cents
    SubscriptionPrice.for(currency, company_limit: owner.company_limit).monthly_cents
  end

  # Platform-wide discount applied to a full year paid up front (info only
  # — billing happens outside the app).
  def annual_discount_percent
    PlatformSetting.current.annual_discount_percent
  end

  # 12 months minus the annual discount, rounded to the cent.
  def annual_subscription_cents
    (monthly_subscription_cents * 12 * (100 - annual_discount_percent) / 100.0).round
  end

  # True when the company operates on the given date's weekday.
  def working_day?(date)
    working_days.include?(date.wday)
  end

  private

  def normalize_working_days
    return if working_days.nil?

    self.working_days = Array(working_days).filter_map { |d| Integer(d, exception: false) }.uniq.sort
  end

  def working_days_are_valid_weekdays
    days = Array(working_days)
    return if days.present? && days.all? { |d| d.is_a?(Integer) && d.between?(0, 6) } && days.uniq.length == days.length

    errors.add(:working_days, "must be a list of distinct weekday numbers (0–6)")
  end

  def logo_is_an_image
    return unless logo.attached?

    errors.add(:logo, "must be an image (JPEG, PNG, WebP)") unless logo.content_type.in?(ALLOWED_LOGO_TYPES)
  end

  def logo_is_not_too_large
    return unless logo.attached?

    errors.add(:logo, "must be smaller than #{MAX_LOGO_SIZE / 1.megabyte}MB") if logo.blob.byte_size > MAX_LOGO_SIZE
  end
end
