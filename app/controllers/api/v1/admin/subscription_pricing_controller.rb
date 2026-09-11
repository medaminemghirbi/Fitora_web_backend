module Api
  module V1
    module Admin
      # The platform's monthly subscription price (one per currency) and the
      # global annual-billing discount. Admin-only. Prices are informational
      # — payment happens outside the app.
      class SubscriptionPricingController < BaseController
        before_action :require_admin!

        # GET /api/v1/admin/subscription_pricing?currency=EUR — defaults to
        # SubscriptionPrice::REFERENCE_CURRENCY (TND) when omitted.
        def show
          render json: pricing_json(SubscriptionPrice.for(params[:currency]))
        end

        # PATCH /api/v1/admin/subscription_pricing?currency=EUR
        #   { monthly_cents?, annual_discount_percent? }
        def update
          price = SubscriptionPrice.for(params[:currency])

          price.monthly_cents = params[:monthly_cents] if params.key?(:monthly_cents)
          setting = PlatformSetting.current
          setting.annual_discount_percent = params[:annual_discount_percent] if params.key?(:annual_discount_percent)

          if price.save && setting.save
            render json: pricing_json(price)
          else
            errors = price.errors.full_messages + setting.errors.full_messages
            render json: { error: errors.first, errors: errors }, status: :unprocessable_entity
          end
        end

        private

        def pricing_json(price)
          {
            currencies: CurrencyCatalog::CODES,
            currency: price.currency,
            monthly_cents: price.monthly_cents,
            annual_discount_percent: PlatformSetting.current.annual_discount_percent,
            annual_cents: (price.monthly_cents * 12 * (100 - PlatformSetting.current.annual_discount_percent) / 100.0).round,
            companies_count: Company.where(currency: price.currency).count
          }
        end
      end
    end
  end
end
