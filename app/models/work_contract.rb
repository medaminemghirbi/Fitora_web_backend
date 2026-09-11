class WorkContract < ApplicationRecord
  STATUSES = { draft: 0, active: 1, ended: 2, terminated: 3 }.freeze
  PAYMENT_METHODS = { bank_transfer: 0, cash: 1, cheque: 2 }.freeze

  belongs_to :company
  # Exactly one of these is set: a back-office staff login, or a coach with
  # no app account. See #employee and exactly_one_employee.
  belongs_to :staff_member, optional: true
  belongs_to :coach, optional: true
  belongs_to :work_contract_type, counter_cache: true

  enum :status, STATUSES
  enum :payment_method, PAYMENT_METHODS, prefix: :pay

  validates :starts_on, presence: true
  validates :gross_monthly_salary, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :weekly_hours, :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :paid_leave_days_per_year, numericality: { greater_than_or_equal_to: 0 }
  validates :notice_period_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :ends_on_after_starts_on
  validate :type_belongs_to_company
  validate :allowances_well_formed
  validate :exactly_one_employee
  validate :employee_belongs_to_company

  scope :active_first, -> { order(Arel.sql("CASE status WHEN 1 THEN 0 ELSE 1 END"), starts_on: :desc) }

  before_validation :normalize_allowances

  # The person this contract employs — a StaffMember or a Coach.
  def employee
    staff_member || coach
  end

  def employee_name
    staff_member&.user&.full_name || coach&.full_name
  end

  def allowances_total
    Array(allowances).sum { |a| a["amount"].to_f }
  end

  # Recurring monthly gross (base + allowances) — the starting point for the
  # RH pré-fiche de paie.
  def total_monthly_gross
    gross_monthly_salary.to_f + allowances_total
  end

  private

  def normalize_allowances
    self.allowances = Array(allowances).filter_map do |raw|
      next unless raw.is_a?(Hash)

      label = raw["label"].presence || raw[:label].presence
      amount = raw["amount"] || raw[:amount]
      next if label.blank?

      { "label" => label.to_s.strip, "amount" => amount.to_f }
    end
  end

  def allowances_well_formed
    return if allowances.is_a?(Array) && allowances.all? { |a| a.is_a?(Hash) && a["label"].present? }

    errors.add(:allowances, "are invalid")
  end

  def ends_on_after_starts_on
    return if ends_on.blank? || starts_on.blank?

    errors.add(:ends_on, "must be on or after the start date") if ends_on < starts_on
  end

  def type_belongs_to_company
    return if work_contract_type.blank?

    errors.add(:work_contract_type, "must belong to the same company") if work_contract_type.company_id != company_id
  end

  def exactly_one_employee
    return if staff_member.present? ^ coach.present?

    errors.add(:base, "must reference exactly one employee (staff member or coach)")
  end

  def employee_belongs_to_company
    errors.add(:staff_member, "must belong to the same company") if staff_member && staff_member.company_id != company_id
    errors.add(:coach, "must belong to the same company") if coach && coach.company_id != company_id
  end
end
