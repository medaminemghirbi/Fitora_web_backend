require "rails_helper"

RSpec.describe "Api::V1::Admin::SubscriptionPricing", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /api/v1/admin/subscription_pricing" do
    it "returns the reference (TND) price + the annual discount by default" do
      SubscriptionPrice.for("TND").update!(monthly_cents: 19_000)

      get "/api/v1/admin/subscription_pricing", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["currency"]).to eq("TND")
      expect(body["monthly_cents"]).to eq(19_000)
      expect(body["annual_discount_percent"]).to eq(10)
      expect(body["annual_cents"]).to eq((19_000 * 12 * 0.9).round)
      expect(body["currencies"]).to include("TND", "EUR")
    end

    it "auto-seeds a requested currency from the reference" do
      SubscriptionPrice.for("TND").update!(monthly_cents: 17_000)

      get "/api/v1/admin/subscription_pricing", params: { currency: "EUR" }, headers: auth_headers(admin)

      expect(response.parsed_body["currency"]).to eq("EUR")
      expect(response.parsed_body["monthly_cents"]).to eq(17_000)
    end

    it "is admin-only" do
      get "/api/v1/admin/subscription_pricing", headers: auth_headers(create(:user, :owner))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/subscription_pricing" do
    it "updates the currency's monthly price and the global annual discount" do
      patch "/api/v1/admin/subscription_pricing",
            params: { currency: "EUR", monthly_cents: 4500, annual_discount_percent: 15 },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(SubscriptionPrice.find_by(currency: "EUR").monthly_cents).to eq(4500)
      expect(PlatformSetting.current.annual_discount_percent).to eq(15)
      expect(response.parsed_body["annual_cents"]).to eq((4500 * 12 * 0.85).round)
    end

    it "rejects an out-of-range discount" do
      patch "/api/v1/admin/subscription_pricing",
            params: { annual_discount_percent: 250 }, headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
