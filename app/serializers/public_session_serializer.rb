# A session as a stranger sees it on a gym's public page.
#
# Deliberately its own serializer rather than a filtered SessionSerializer:
# that one is for people inside a gym, and anything added to it later — a
# price, a client, an internal note — would silently become public here.
# This one can only ever show what is listed below.
class PublicSessionSerializer
  def initialize(session)
    @session = session
  end

  def as_json(*)
    {
      id: session.id,
      activity_name: session.activity.name,
      activity_emoji: session.activity.emoji,
      coach_name: session.coach&.full_name,
      starts_at: session.starts_at,
      ends_at: session.ends_at,
      capacity: session.capacity,
      # How much room is left, never how many people are in it: a gym's real
      # attendance is its own business.
      spots_left: [ session.capacity - session.confirmed_bookings_count, 0 ].max,
      full: session.confirmed_bookings_count >= session.capacity
    }
  end

  private

  attr_reader :session
end
