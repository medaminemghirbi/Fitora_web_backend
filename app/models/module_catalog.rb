# The catalogue of product features. Every company has every feature — the
# whole product is included in one subscription (see SubscriptionPrice).
# This is no longer an activation/billing concept: it's just the map from a
# feature to the Permission::CATALOG entries it unlocks, used by
# Permissions::Resolve, plus the key list the owner's subscription page
# renders as "what's included".
#
# Display names/descriptions are i18n keys on the frontend (`modules.<key>`);
# nothing here is user-facing text.
module ModuleCatalog
  BASE_KEY = "base".freeze

  # Permissions every company has no matter what: the dashboard and the
  # establishments/settings screens.
  BASE_PERMISSIONS = %w[reports locations].freeze

  # key => { permissions: [...] } — the Permission::CATALOG keys each
  # feature unlocks. Order is the display order on the subscription page.
  #
  # Only features with real code behind them belong here. client_portal,
  # messaging, pos, maintenance and analytics were removed (no backend or
  # frontend anywhere); fleet, inventory and appointments were real but cut
  # by the gym-only product decision. Re-add a key once its feature exists.
  CATALOG = {
    "clients"     => { permissions: %w[clients] },
    "classes"     => { permissions: %w[activities sessions] },
    "bookings"    => { permissions: %w[bookings checkin] },
    "memberships" => { permissions: %w[contracts contract_types] },
    "billing"     => { permissions: %w[payments] },
    "hr"          => { permissions: %w[coaches] },
    "ged"         => { permissions: %w[company_library] },
    "payroll"     => { permissions: %w[] },
    "suppliers"   => { permissions: %w[] }
  }.freeze

  KEYS = CATALOG.keys.freeze

  # Every permission the product exposes — every company has all of them.
  ALL_PERMISSIONS = (BASE_PERMISSIONS + CATALOG.values.flat_map { |v| v[:permissions] }).uniq.freeze

  def self.exists?(key)
    key.to_s == BASE_KEY || CATALOG.key?(key.to_s)
  end

  # Kept for call-site compatibility (Permissions::Resolve) — the argument
  # is ignored now that every feature is always on.
  def self.permissions_for(_enabled_keys = nil)
    ALL_PERMISSIONS
  end
end
