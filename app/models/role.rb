# A company-scoped, editable set of permissions that staff logins are
# assigned to. Every company starts with three built-in roles (owner,
# receptionist, coach) seeded from DEFAULTS; the owner can rename them,
# change their permissions (except "owner"), or add custom roles
# ("Comptable", "Assistant·e", …) via the roles editor.
#
# The built-in roles keep their `key` (SYSTEM_KEYS) so the backend and
# frontend still recognise them; a custom role gets a `key` slugified from
# its name, fixed at creation.
class Role < ApplicationRecord
  belongs_to :company
  has_many :staff_members, foreign_key: :role_id, inverse_of: :assigned_role, dependent: :restrict_with_error

  SYSTEM_KEYS = %w[owner moderator receptionist coach].freeze

  DEFAULTS = {
    "owner" => {
      name: "Propriétaire",
      permissions: Permission::ALL
    },
    # Runs the gym day to day AND staffs it: the one role below the owner
    # that can add coaches. Still not the catalogues (activities, plans) or
    # the money settings — those stay the owner's.
    #
    # "payments" without "revenue" is the distinction that matters: taking
    # money at the desk is the job, reading what the gym earns is not.
    "moderator" => {
      name: "Modérateur",
      permissions: %w[sessions bookings clients contracts payments checkin reports coaches]
    },
    # Front desk / daily gym operations. NOT the catalogs (activities,
    # membership plans), the coach roster, or opening hours — the owner can
    # grant those per-role via the roles editor.
    "receptionist" => {
      name: "Réception",
      permissions: %w[sessions bookings clients contracts payments checkin reports]
    },
    "coach" => {
      name: "Coach",
      permissions: %w[checkin]
    }
  }.freeze

  before_validation :normalise

  validates :key, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true

  scope :ordered, -> { order(:position, :name) }

  # A built-in role can be re-permissioned and renamed but not deleted or
  # re-keyed; a custom role can be deleted once nothing is assigned to it.
  def builtin?
    self[:builtin]
  end

  def deletable?
    !builtin? && staff_members.none?
  end

  def self.seed_defaults_for(company)
    DEFAULTS.each_with_index do |(key, attrs), index|
      role = company.roles.find_or_initialize_by(key: key)
      if role.new_record?
        role.name = attrs[:name]
        role.permissions = attrs[:permissions]
      end
      role.builtin = true
      role.position = index
      role.save!
    end
  end

  private

  def normalise
    self.permissions = Permission.sanitize(permissions)
    # A custom role has no key on create — slugify it from the name, once.
    self.key = (key.presence || name).to_s.strip.parameterize(separator: "_").presence
  end
end
