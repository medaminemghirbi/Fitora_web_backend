class ContractTypeSerializer
  def initialize(plan)
    @plan = plan
  end

  def as_json(*)
    {
      id: plan.id,
      company_id: plan.company_id,
      name: plan.name,
      description: plan.description,
      price: plan.price,
      currency: plan.currency,
      billing_period: plan.billing_period,
      duration_days: plan.duration_days,
      session_count: plan.session_count,
      unlimited_bookings: plan.unlimited_bookings,
      booking_limit: plan.booking_limit,
      priority_booking: plan.priority_booking,
      color: plan.color,
      active: plan.active,
      location_ids: plan.location_ids,
      activity_ids: plan.activity_ids
    }
  end

  private

  attr_reader :plan
end
