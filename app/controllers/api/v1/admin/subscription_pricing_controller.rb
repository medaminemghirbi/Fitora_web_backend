module Api
  module V1
    module Admin
      # The platform's monthly subscription price per currency AND
      # company-limit tier (1 / 3 / unlimited companies), plus the global
      # annual-billing discount. Admin-only. Prices are informational —
      # payment happens outside the app.
      class SubscriptionPricingController < BaseController
        before_action :require_admin!

        # GET /api/v1/admin/subscription_pricing?currency=EUR — all three
        # tiers for one currency at once (defaults to
        # SubscriptionPrice::REFERENCE_CURRENCY, TND, when omitted).
        def show
          currency = params[:currency].presence || SubscriptionPrice::REFERENCE_CURRENCY
          render json: pricing_json(currency)
        end

        # PATCH /api/v1/admin/subscription_pricing?currency=EUR
        #   { tiers: { "1" => monthly_cents, "3" => ..., "0" => ... }, annual_discount_percent? }
        # Tier keys are SubscriptionPrice::TIERS (0 = unlimited); any
        # subset may be sent — omitted tiers are left as-is.
        def update
          currency = params[:currency].presence || SubscriptionPrice::REFERENCE_CURRENCY
          setting = PlatformSetting.current
          setting.annual_discount_percent = params[:annual_discount_percent] if params.key?(:annual_discount_percent)

          tiers = params[:tiers].present? ? params[:tiers].permit(*SubscriptionPrice::TIERS.map(&:to_s)).to_h : {}
          rows = tiers.map do |tier, monthly_cents|
            price = SubscriptionPrice.for(currency, company_limit: tier.to_i)
            price.monthly_cents = monthly_cents
            price
          end

          if rows.all?(&:valid?) && setting.valid?
            ActiveRecord::Base.transaction do
              rows.each(&:save!)
              setting.save!
            end
            render json: pricing_json(currency)
          else
            errors = rows.flat_map { |r| r.errors.full_messages } + setting.errors.full_messages
            render json: { error: errors.first, errors: errors }, status: :unprocessable_content
          end
        end

        private

        def pricing_json(currency)
          discount = PlatformSetting.current.annual_discount_percent

          tiers = SubscriptionPrice::TIERS.map do |tier|
            price = SubscriptionPrice.for(currency, company_limit: tier)
            {
              company_limit: tier,
              unlimited: price.unlimited?,
              monthly_cents: price.monthly_cents,
              annual_cents: (price.monthly_cents * 12 * (100 - discount) / 100.0).round
            }
          end

          {
            currencies: CurrencyCatalog::CODES,
            currency: currency,
            annual_discount_percent: discount,
            tiers: tiers,
            companies_count: Company.where(currency: currency).count
          }
        end
      end
    end
  end
end
