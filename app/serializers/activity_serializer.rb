class ActivitySerializer
  def initialize(activity)
    @activity = activity
  end

  def as_json(*)
    {
      id: activity.id,
      location_id: activity.location_id,
      name: activity.name,
      emoji: activity.emoji,
      description: activity.description,
      session_format: activity.session_format,
      duration: activity.duration,
      capacity: activity.capacity,
      active: activity.active
    }
  end

  private

  attr_reader :activity
end
