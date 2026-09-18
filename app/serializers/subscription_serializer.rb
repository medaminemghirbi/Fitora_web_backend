class SubscriptionSerializer
  def initialize(subscription)
    @subscription = subscription
  end

  def as_json(*)
    return nil if subscription.nil?

    {
      id: subscription.id,
      # The access, and nothing else. No date is compared to read it.
      active: subscription.active,
      billing_period: subscription.billing_period,
      lock_reason: subscription.lock_reason,
      # What the invoices say, for the screens that show a countdown.
      paid_through: subscription.paid_through,
      current_period_paid: subscription.current_period_paid?,
      days_before_lock: subscription.days_before_lock
    }
  end

  private

  attr_reader :subscription
end
