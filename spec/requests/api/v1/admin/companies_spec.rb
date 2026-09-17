require "rails_helper"

RSpec.describe "Api::V1::Admin::Companies", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "authorization" do
    it "forbids an owner from accessing the admin companies list" do
      owner = create(:user, :owner)

      get "/api/v1/admin/companies", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids org-scoped staff from accessing the admin companies list" do
      staff = create(:staff_member)

      get "/api/v1/admin/companies", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/admin/companies" do
    it "lists every company across every owner, not just one" do
      company_a = create(:company)
      company_b = create(:company)
      create(:subscription, company: company_a)
      create(:subscription, company: company_b)

      get "/api/v1/admin/companies", headers: auth_headers(admin)

      ids = response.parsed_body["companies"].map { |o| o["id"] }
      expect(ids).to include(company_a.id, company_b.id)
    end

    it "filters by ?q= on company name, city or owner" do
      match = create(:company, name: "Zen Yoga Monastir", city: "Monastir")
      other = create(:company, name: "Iron Gym Tunis", city: "Tunis")

      get "/api/v1/admin/companies", params: { q: "monastir" }, headers: auth_headers(admin)

      ids = response.parsed_body["companies"].map { |o| o["id"] }
      expect(ids).to include(match.id)
      expect(ids).not_to include(other.id)
      expect(response.parsed_body["meta"]["total"]).to eq(1)
    end
  end

  describe "GET /api/v1/admin/companies/:id" do
    it "returns the company with its currency/locale and the option lists" do
      company = create(:company, currency: "TND", locale: "fr")

      get "/api/v1/admin/companies/#{company.id}", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["company"]).to include("currency" => "TND", "currency_symbol" => "DT", "locale" => "fr")
      expect(body["currency_options"].map { |c| c["code"] }).to include("TND", "EUR", "USD")
      expect(body["currency_options"].find { |c| c["code"] == "EUR" }).to include("symbol" => "€")
      expect(body["locale_options"]).to eq(%w[fr en ar])
    end
  end

  describe "PATCH /api/v1/admin/companies/:id/settings" do
    it "sets the tenant currency and language" do
      company = create(:company, currency: "TND", locale: "fr")

      patch "/api/v1/admin/companies/#{company.id}/settings",
            params: { company: { currency: "EUR", locale: "en" } },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.reload).to have_attributes(currency: "EUR", locale: "en")
      expect(response.parsed_body["company"]).to include("currency_symbol" => "€")
    end

    it "422s on a currency outside the catalogue" do
      company = create(:company)
      patch "/api/v1/admin/companies/#{company.id}/settings",
            params: { company: { currency: "BTC" } }, headers: auth_headers(admin)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "422s on an unsupported language" do
      company = create(:company)
      patch "/api/v1/admin/companies/#{company.id}/settings",
            params: { company: { locale: "de" } }, headers: auth_headers(admin)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "is admin-only" do
      company = create(:company)
      patch "/api/v1/admin/companies/#{company.id}/settings",
            params: { company: { currency: "EUR" } }, headers: auth_headers(create(:user, :owner))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/companies/:id/subscription" do
    it "overrides a company's access status directly, with no payment involved" do
      company = create(:company)
      create(:subscription, company: company, status: :inactive)

      patch "/api/v1/admin/companies/#{company.id}/subscription",
            params: { status: "active" },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.reload.subscription.status).to eq("active")
      expect(Payment.count).to eq(0)
    end

    it "creates a subscription when the company has none yet" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/subscription",
            params: { status: "active" },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.reload.subscription).to be_present
      expect(company.subscription.status).to eq("active")
    end

    it "activates a real subscription with a billing period and clears the owner's request" do
      company = create(:company)
      sub = create(:subscription, company: company, status: :active, expires_at: 5.days.from_now)
      sub.request_upgrade!(period: "yearly")

      patch "/api/v1/admin/companies/#{company.id}/subscription",
            params: { status: "active", billing_period: "yearly", expires_at: "2027-09-09" },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      sub.reload
      expect(sub.billing_period).to eq("yearly")
      expect(sub.on_trial?).to be false
      expect(sub.upgrade_requested?).to be false
      expect(response.parsed_body["company"]["subscription"]).to include("billing_period" => "yearly", "on_trial" => false)
    end
  end

  describe "PATCH /api/v1/admin/companies/:id/debt" do
    it "records the company's outstanding balance" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/debt",
            params: { debt_cents: 15_000 },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.reload.debt_cents).to eq(15_000)
      expect(response.parsed_body["company"]["debt_cents"]).to eq(15_000)
    end

    it "rejects a negative balance" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/debt",
            params: { debt_cents: -100 },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/admin/companies/:id/company_limit" do
    it "raises the owner's tier, affecting every company they run" do
      company = create(:company)
      other_company = create(:company, owner: company.owner)

      patch "/api/v1/admin/companies/#{company.id}/company_limit",
            params: { company_limit: 3 },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.owner.reload.company_limit).to eq(3)
      expect(response.parsed_body["company"]["owner"]["company_limit"]).to eq(3)
      expect(response.parsed_body["company"]["owner"]["companies_count"]).to eq(2) # company + other_company, same owner
      expect(other_company.reload.owner.company_limit).to eq(3)
    end

    it "sets the unlimited tier with a blank value" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/company_limit",
            params: { company_limit: "" },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.owner.reload.company_limit).to be_nil
    end

    it "rejects a tier that isn't 1, 3, or unlimited" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/company_limit",
            params: { company_limit: 2 },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "logs an audit entry" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/company_limit", params: { company_limit: 3 }, headers: auth_headers(admin)

      log = AuditLog.last
      expect(log.action).to eq("owner.company_limit_changed")
      expect(log.metadata["to"]).to eq(3)
    end

    it "is admin-only" do
      company = create(:company)

      patch "/api/v1/admin/companies/#{company.id}/company_limit",
            params: { company_limit: 3 },
            headers: auth_headers(create(:user, :owner))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/admin/companies/:id/impersonate" do
    it "issues a real session for the company's owner, not the admin" do
      company = create(:company)

      post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["id"]).to eq(company.owner.id)
      expect(response.parsed_body["user"]["role"]).to eq("owner")
      expect(response.parsed_body["token"]).to be_present
    end

    it "the issued token actually authenticates as the owner on a normal endpoint" do
      company = create(:company)

      post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(admin)
      token = response.parsed_body["token"]

      get "/api/v1/company", headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["company"]["id"]).to eq(company.id)
    end

    it "records who impersonated in the audit log" do
      company = create(:company)

      post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(admin)

      log = AuditLog.order(:created_at).last
      expect(log.action).to eq("admin.impersonation_started")
      expect(log.company_id).to eq(company.id)
      expect(log.metadata["admin_id"]).to eq(admin.id)
    end

    it "forbids a non-admin from impersonating" do
      company = create(:company)
      owner = create(:user, :owner)

      post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
