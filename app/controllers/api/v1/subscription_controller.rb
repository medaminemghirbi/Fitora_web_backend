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
          locations_used: company&.locations&.count || 0,
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
          included_modules: ModuleCatalog::KEYS
        }
      end
    end
  end
end
