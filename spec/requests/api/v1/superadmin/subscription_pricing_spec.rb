require "rails_helper"

RSpec.describe "Api::V1::Superadmin::SubscriptionPricing", type: :request do
  let(:superadmin) { create(:user, :superadmin) }

  describe "GET /api/v1/superadmin/subscription_pricing" do
    it "returns all three tiers for the reference (TND) currency + the annual discount by default" do
      SubscriptionPrice.for("TND", company_limit: 1).update!(monthly_cents: 19_000)

      get "/api/v1/superadmin/subscription_pricing", headers: auth_headers(superadmin)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["currency"]).to eq("TND")
      expect(body["annual_discount_percent"]).to eq(10)
      expect(body["currencies"]).to include("TND", "EUR")

      tier1 = body["tiers"].find { |t| t["company_limit"] == 1 }
      expect(tier1["monthly_cents"]).to eq(19_000)
      expect(tier1["annual_cents"]).to eq((19_000 * 12 * 0.9).round)
      expect(body["tiers"].map { |t| t["company_limit"] }).to match_array([ 1, 3, SubscriptionPrice::UNLIMITED ])
    end

    it "auto-seeds a requested currency's tiers from the reference" do
      SubscriptionPrice.for("TND", company_limit: 1).update!(monthly_cents: 17_000)

      get "/api/v1/superadmin/subscription_pricing", params: { currency: "EUR" }, headers: auth_headers(superadmin)

      body = response.parsed_body
      expect(body["currency"]).to eq("EUR")
      expect(body["tiers"].find { |t| t["company_limit"] == 1 }["monthly_cents"]).to eq(17_000)
    end

    it "is superadmin-only" do
      get "/api/v1/superadmin/subscription_pricing", headers: auth_headers(create(:user, :admin))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/superadmin/subscription_pricing" do
    it "updates one or more of a currency's tiers and the global annual discount" do
      patch "/api/v1/superadmin/subscription_pricing",
            params: { currency: "EUR", tiers: { "1" => 4500, "3" => 9000 }, annual_discount_percent: 15 },
            headers: auth_headers(superadmin)

      expect(response).to have_http_status(:ok)
      expect(SubscriptionPrice.for("EUR", company_limit: 1).monthly_cents).to eq(4500)
      expect(SubscriptionPrice.for("EUR", company_limit: 3).monthly_cents).to eq(9000)
      expect(PlatformSetting.current.annual_discount_percent).to eq(15)

      tier1 = response.parsed_body["tiers"].find { |t| t["company_limit"] == 1 }
      expect(tier1["annual_cents"]).to eq((4500 * 12 * 0.85).round)
    end

    it "updates the unlimited tier via the 0 sentinel key" do
      patch "/api/v1/superadmin/subscription_pricing",
            params: { currency: "EUR", tiers: { "0" => 80_000 } },
            headers: auth_headers(superadmin)

      expect(response).to have_http_status(:ok)
      expect(SubscriptionPrice.for("EUR", company_limit: SubscriptionPrice::UNLIMITED).monthly_cents).to eq(80_000)
    end

    it "leaves tiers not mentioned in the request untouched" do
      SubscriptionPrice.for("EUR", company_limit: 3).update!(monthly_cents: 9000)

      patch "/api/v1/superadmin/subscription_pricing", params: { currency: "EUR", tiers: { "1" => 4500 } }, headers: auth_headers(superadmin)

      expect(SubscriptionPrice.for("EUR", company_limit: 3).monthly_cents).to eq(9000)
    end

    it "rejects an out-of-range discount" do
      patch "/api/v1/superadmin/subscription_pricing",
            params: { annual_discount_percent: 250 }, headers: auth_headers(superadmin)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
