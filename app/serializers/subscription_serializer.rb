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
      upgrade_requested_period: subscription.upgrade_requested_period
    }
  end

  private

  attr_reader :subscription
end
