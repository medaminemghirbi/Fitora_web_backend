class SessionSerializer
  def initialize(session, current_client: nil)
    @session = session
    @current_client = current_client
  end

  def as_json(*)
    {
      id: session.id,
      activity_id: session.activity_id,
      activity_name: session.activity.name,
      activity_emoji: session.activity.emoji,
      location_id: session.location_id,
      location_name: session.location.name,
      coach_id: session.coach_id,
      coach_name: session.coach&.full_name,
      starts_at: session.starts_at,
      ends_at: session.ends_at,
      capacity: session.capacity,
      confirmed_count: session.confirmed_bookings_count,
      price: session.price,
      status: session.status,
      availability: availability,
      already_booked: already_booked?
    }
  end

  private

  attr_reader :session, :current_client

  def availability
    return "cancelled" if session.cancelled?
    return "full" if session.full?

    "available"
  end

  # Was previously querying bookings.user_id — a column that doesn't exist
  # (Booking belongs_to :client, never :user); this parameter had no working
  # caller, so nothing regresses in fixing it for Api::V1::Client::SessionsController.
  def already_booked?
    return false if current_client.nil?

    session.bookings.held.where(client_id: current_client.id).exists?
  end
end
