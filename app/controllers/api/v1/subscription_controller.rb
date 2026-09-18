module Api
  module V1
    # The gym's own view of its Fitora access: whether it is open, until
    # when, and every invoice it has been issued.
    #
    # There is nothing to ask for here any more. A gym settles with Fitora
    # directly; Fitora confirms, and the invoice appears.
    class SubscriptionController < BaseController
      before_action :require_owner!

      # GET /api/v1/subscription
      def show
        company = current_company
        subscription = company&.subscription

        render json: {
          subscription: SubscriptionSerializer.new(subscription).as_json,
          invoices: (company ? company.invoices.newest_first.map { |i| InvoiceSerializer.new(i).as_json } : []),
          clients_used: company&.clients&.count || 0,
          staff_used: company&.staff_members&.count || 0,
          currency: company&.currency,
          currency_symbol: company&.currency_symbol,
          monthly_subscription_cents: company&.monthly_subscription_cents || 0,
          annual_subscription_cents: company&.annual_subscription_cents || 0,
          annual_discount_percent: company&.annual_discount_percent || 0,
          arrears_cents: subscription&.arrears_cents || 0,
          included_modules: ModuleCatalog::KEYS,
          # How many companies this owner may run, and what each tier costs
          # in their currency — the full comparison, not just their own tier.
          company_limit: current_user.company_limit,
          companies_count: current_user.companies.count,
          company_limit_reached: current_user.company_limit_reached?,
          company_tiers: company_tiers(company&.currency)
        }
      end

      private

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
