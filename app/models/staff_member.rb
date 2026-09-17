class StaffMember < ApplicationRecord
  # The *kind* of staff login, not its permissions. `coach` gets the mobile
  # app + the coach shell + a linked Coach row; `receptionist` is any
  # back-office web login. The actual permission set lives on the assigned
  # Role (see #permission_keys); a custom role still has one of these kinds.
  ROLES = { receptionist: 0, coach: 1 }.freeze

  # Legacy fallback only — kept for staff rows that predate the Role table
  # and haven't been backfilled. Live permission resolution goes through
  # #permission_keys, which prefers the assigned Role. "checkin" covers
  # attendance-marking rights; "sessions" is specifically the right to
  # *restructure* the schedule — everyone can *view* the calendar, see
  # BaseController#require_staff!.
  CAPABILITIES = {
    receptionist: %i[sessions bookings clients contracts payments checkin reports],
    coach: %i[checkin]
  }.freeze

  belongs_to :user
  belongs_to :company
  belongs_to :coach, optional: true
  # The configurable role this staff login is assigned to. Optional during
  # the migration window; #permission_keys falls back to CAPABILITIES when
  # it's nil.
  belongs_to :assigned_role, class_name: "Role", foreign_key: :role_id, optional: true, inverse_of: :staff_members,
                              counter_cache: :staff_members_count


  enum :role, ROLES

  # For a staff row on a built-in role, keep `assigned_role` pointing at the
  # Role whose key matches the enum kind, so permissions resolve through the
  # Role table. A caller that assigns a *custom* role (roles editor) wins —
  # the sync bails out in that case.
  before_validation :sync_assigned_role_from_enum

  validates :user_id, uniqueness: true
  validate :coach_only_for_coach_role
  validate :coach_belongs_to_same_company

  scope :active, -> { where(active: true) }

  def can?(capability)
    permission_keys.include?(capability.to_s)
  end

  def full_name
    user&.full_name
  end

  # True on the person's birthday (day + month), any year.
  def birthday_today?(on: Date.current)
    birthdate.present? && birthdate.strftime("%m-%d") == on.strftime("%m-%d")
  end

  # The key of the effective role — the assigned Role's key, else the enum
  # kind. What the UI and audit log identify the role by.
  def role_key
    assigned_role&.key || role
  end

  # The resolved permission list for this staff login: the assigned Role's
  # permissions, or — for rows not yet linked to a Role — the legacy
  # capability map for the enum value.
  def permission_keys
    return assigned_role.permissions if assigned_role

    CAPABILITIES.fetch(role.to_sym, []).map(&:to_s)
  end

  private

  def sync_assigned_role_from_enum
    return if company_id.blank? || role.blank?
    # Never clobber a custom role the caller deliberately assigned.
    return if assigned_role && !assigned_role.builtin?

    match = company.roles.find_by(key: role.to_s)
    self.assigned_role = match if match && role_id != match.id
  end

  def coach_only_for_coach_role
    errors.add(:coach, "can only be set for the coach role") if coach.present? && !coach?
  end

  def coach_belongs_to_same_company
    return if coach.blank?

    errors.add(:coach, "must belong to the same company") if coach.company_id != company_id
  end
end
