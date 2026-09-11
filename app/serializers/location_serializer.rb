class LocationSerializer
  def initialize(location)
    @location = location
  end

  def as_json(*)
    {
      id: location.id,
      company_id: location.company_id,
      name: location.name,
      description: location.description,
      phone: location.phone,
      email: location.email,
      address: location.address,
      city: location.city,
      latitude: location.latitude,
      longitude: location.longitude,
      timezone: location.timezone,
      active: location.active,
      business_hours_start: location.business_hours_start&.strftime("%H:%M"),
      business_hours_end: location.business_hours_end&.strftime("%H:%M")
    }
  end

  private

  attr_reader :location
end
