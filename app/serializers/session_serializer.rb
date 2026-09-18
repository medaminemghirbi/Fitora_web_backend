class SessionSerializer
  def initialize(session)
    @session = session
  end

  def as_json(*)
    {
      id: session.id,
      activity_id: session.activity_id,
      activity_name: session.activity.name,
      activity_emoji: session.activity.emoji,
      company_id: session.company_id,
      company_name: session.company.name,
      coach_id: session.coach_id,
      coach_name: session.coach&.full_name,
      starts_at: session.starts_at,
      ends_at: session.ends_at,
      capacity: session.capacity,
      confirmed_count: session.confirmed_bookings_count,
      price: session.price,
      status: session.status,
      availability: availability
    }
  end

  private

  attr_reader :session

  def availability
    return "cancelled" if session.cancelled?
    return "full" if session.full?

    "available"
  end
end
