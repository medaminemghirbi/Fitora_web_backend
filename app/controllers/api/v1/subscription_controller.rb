module Api
  module V1
    # The owner's view of their Fitora subscription. Access is granted and
    # billed off-app by a platform admin; the owner can request activation
    # from here (see #request_upgrade), but never pays in-app.
    class SubscriptionController < BaseController
      before_action :require_owner!
      before_action :require_company!, only: [ :request_upgrade, :cancel_upgrade ]

      # GET /api/v1/subscription
      def show
        render json: subscription_payload
      end

      # POST /api/v1/subscription/request_upgrade  { period: "monthly" | "yearly" }
      def request_upgrade
        subscription = current_company.subscription
        return render(json: { error: "no_subscription" }, status: :unprocessable_content) if subscription.nil?

        subscription.request_upgrade!(period: params[:period])
        AuditLogs::Record.call(
          company: current_company, user: current_user, action: "subscription.upgrade_requested",
          auditable: subscription, metadata: { period: subscription.upgrade_requested_period }
        )
        render json: subscription_payload
      end

      # DELETE /api/v1/subscription/request_upgrade
      def cancel_upgrade
        current_company.subscription&.cancel_upgrade_request!
        render json: subscription_payload
      end

      private

      def subscription_payload
        company = current_company
        subscription = company&.subscription

        {
          subscription: SubscriptionSerializer.new(subscription).as_json,
          clients_used: company&.clients&.count || 0,
          staff_used: company&.staff_members&.count || 0,
          locked: subscription&.locked? || false,
          trial_days_remaining: subscription&.days_remaining,
          on_trial: subscription.nil? || subscription.on_trial?,
          currency: company&.currency,
          currency_symbol: company&.currency_symbol,
          monthly_subscription_cents: company&.monthly_subscription_cents || 0,
          annual_subscription_cents: company&.annual_subscription_cents || 0,
          annual_discount_percent: company&.annual_discount_percent || 0,
          debt_cents: company&.debt_cents || 0,
          included_modules: ModuleCatalog::KEYS,
          # How many companies this owner may run, and what each tier
          # costs in their currency — Company#monthly_subscription_cents
          # above is just "the price of the tier they're already on";
          # this is the full comparison for an upgrade prompt.
          company_limit: current_user.company_limit,
          companies_count: current_user.companies.count,
          company_limit_reached: current_user.company_limit_reached?,
          company_tiers: company_tiers(company&.currency)
        }
      end

      def company_tiers(currency)
        return [] if currency.blank?

        discount = PlatformSetting.current.annual_discount_percent
        SubscriptionPrice::TIERS.map do |tier|
          price = SubscriptionPrice.for(currency, company_limit: tier)
          {
            company_limit: price.unlimited? ? nil : tier,
            monthly_cents: price.monthly_cents,
            annual_cents: (price.monthly_cents * 12 * (100 - discount) / 100.0).round
          }
        end
      end
    end
  end
end
