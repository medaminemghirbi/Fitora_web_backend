# A gym as a stranger sees it in the directory. Every field here is one the
# gym publishes about itself; nothing is derived from its members or its
# books. Kept separate from CompanySerializer on purpose — that one is the
# owner's own view and carries settings this must never leak.
class GymSerializer
  def initialize(company, detailed: false)
    @company = company
    @detailed = detailed
  end

  def as_json(*)
    base = {
      id: company.id,
      slug: company.slug,
      name: company.name,
      city: company.city,
      country: company.country,
      description: company.description,
      logo_url: logo_url,
      primary_color: company.primary_color,
      currency: company.currency,
      # Only present when the directory was asked for the nearest gyms, and
      # only for a gym that has published its coordinates.
      distance_km: distance_km,
      activity_names: activity_names
    }

    return base unless detailed

    base.merge(
      address: company.address,
      phone: company.phone,
      email: company.email,
      latitude: company.latitude,
      longitude: company.longitude,
      timezone: company.timezone,
      working_days: company.working_days,
      activities: activities.map { |a| { id: a.id, name: a.name, emoji: a.emoji, session_format: a.session_format } },
      # The week ahead, so someone can tell whether this gym has a class that
      # fits their evenings before joining anything. Prices are NOT here: the
      # schedule sells the gym, the pricing is a conversation.
      sessions: upcoming_sessions.map { |s| PublicSessionSerializer.new(s).as_json }
    )
  end

  private

  attr_reader :company, :detailed

  def distance_km
    raw = company.attributes["distance_km"]
    raw && raw.to_f.round(1)
  end

  def activities
    @activities ||= company.activities.where(active: true).order(:name)
  end

  # Seven days is what a person actually plans around, and it keeps a gym
  # from publishing its whole term at once.
  def upcoming_sessions
    company.sessions.where(status: :scheduled)
             .where(starts_at: Time.current..7.days.from_now)
             .includes(:activity, :coach)
             .order(:starts_at)
             .limit(60)
  end

  def activity_names
    activities.limit(6).pluck(:name)
  end

  def logo_url
    return nil unless company.logo.attached?

    Rails.application.routes.url_helpers.rails_blob_url(company.logo, only_path: true)
  end
end
