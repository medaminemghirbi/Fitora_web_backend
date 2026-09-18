require "rails_helper"

RSpec.describe "Api::V1::Subscription", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/subscription" do
    it "reports access as the boolean it is, with the invoices behind it" do
      create(:subscription, company: company)
      create(:invoice, :current, company: company, number: "FIT-2026-0001")

      get "/api/v1/subscription", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["subscription"]["active"]).to be true
      expect(body["subscription"]["current_period_paid"]).to be true
      expect(body["invoices"].map { |i| i["number"] }).to eq([ "FIT-2026-0001" ])
    end

    it "counts what is owed rather than taking it from a field" do
      create(:subscription, company: company)
      create(:invoice, company: company, period_start: Date.current - 60, period_end: Date.current.prev_month.end_of_month)

      get "/api/v1/subscription", headers: auth_headers(owner)

      expect(response.parsed_body["arrears_cents"]).to eq(company.monthly_subscription_cents)
    end

    it "is closed to staff — it is the owner's business" do
      staff = create(:staff_member, company: company, role: :receptionist).user
      create(:subscription, company: company)

      get "/api/v1/subscription", headers: auth_headers(staff)

      expect(response).to have_http_status(:forbidden)
    end

    it "no longer offers anything to ask for" do
      post "/api/v1/subscription/request_upgrade", headers: auth_headers(owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/invoices" do
    it "returns the gym's own, newest first" do
      create(:subscription, company: company)
      create(:invoice, company: company, number: "FIT-2026-0001", period_start: Date.current - 60, period_end: Date.current - 31)
      create(:invoice, company: company, number: "FIT-2026-0002", period_start: Date.current - 30, period_end: Date.current)

      get "/api/v1/invoices", headers: auth_headers(owner)

      expect(response.parsed_body["invoices"].map { |i| i["number"] }).to eq([ "FIT-2026-0002", "FIT-2026-0001" ])
    end

    it "never returns another gym's" do
      create(:subscription, company: company)
      create(:invoice, company: create(:company))

      get "/api/v1/invoices", headers: auth_headers(owner)

      expect(response.parsed_body["invoices"]).to be_empty
    end

    it "404s on another gym's invoice rather than admitting it exists" do
      create(:subscription, company: company)
      theirs = create(:invoice, company: create(:company))

      get "/api/v1/invoices/#{theirs.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end
end
