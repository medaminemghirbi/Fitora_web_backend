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
      currency: plan.currency,
      billing_period: plan.billing_period,
      duration_days: plan.duration_days,
      session_count: plan.session_count,
      unlimited_bookings: plan.unlimited_bookings,
      booking_limit: plan.booking_limit,
      priority_booking: plan.priority_booking,
      color: plan.color,
      active: plan.active,
      activity_ids: plan.activity_ids,
      # The pricing grid: what each activity costs under this plan.
      activity_prices: plan.contract_type_activities.includes(:activity).map { |row|
        { activity_id: row.activity_id, activity_name: row.activity.name, activity_emoji: row.activity.emoji, price: row.price }
      }
    }
  end

  private

  attr_reader :plan
end
