class AbsenceTypeSerializer
  def initialize(type)
    @type = type
  end

  def as_json(*)
    {
      id: type.id,
      name: type.name,
      abbreviation: type.abbreviation,
      paid: type.paid,
      active: type.active,
      position: type.position,
      leave_requests_count: type.leave_requests.size
    }
  end

  private

  attr_reader :type
end
