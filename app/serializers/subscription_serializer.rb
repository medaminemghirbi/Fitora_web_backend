class SubscriptionSerializer
  def initialize(subscription)
    @subscription = subscription
  end

  def as_json(*)
    return nil if subscription.nil?

    {
      id: subscription.id,
      status: subscription.status,
      starts_at: subscription.starts_at,
      expires_at: subscription.expires_at,
      billing_period: subscription.billing_period,
      on_trial: subscription.on_trial?,
      upgrade_requested_at: subscription.upgrade_requested_at,
      upgrade_requested_period: subscription.upgrade_requested_period,
      # Paying, month by month. `current_period_paid` is the boolean an
      # admin thinks in; the date behind it is what makes it true.
      paid_through: subscription.paid_through,
      current_period_paid: subscription.current_period_paid?,
      payment_overdue: subscription.payment_overdue?,
      days_before_lock: subscription.days_before_lock,
      lock_reason: subscription.lock_reason
    }
  end

  private

  attr_reader :subscription
end
