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

  describe "GET /api/v1/admin/companies?awaiting=1" do
    def asked!(company, at:, period: nil)
      company.subscription.update!(upgrade_requested_at: at, upgrade_requested_period: period)
    end

    it "narrows to the gyms waiting on an answer, longest wait first" do
      quiet = create(:company, name: "Quiet")
      create(:subscription, company: quiet)

      longest = create(:company, name: "Longest")
      create(:subscription, company: longest)
      asked!(longest, at: 5.days.ago)

      recent = create(:company, name: "Recent")
      create(:subscription, company: recent)
      asked!(recent, at: 1.hour.ago)

      get "/api/v1/admin/companies", params: { awaiting: "1" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["companies"].map { |c| c["name"] }).to eq([ "Longest", "Recent" ])
    end

    it "counts them even when the list is not narrowed, so nothing has to be opened to notice" do
      waiting = create(:company, name: "Waiting")
      create(:subscription, company: waiting)
      asked!(waiting, at: 2.days.ago)
      create(:subscription, company: create(:company, name: "Quiet"))

      get "/api/v1/admin/companies", headers: auth_headers(admin)

      expect(response.parsed_body["awaiting_count"]).to eq(1)
      expect(response.parsed_body["companies"].map { |c| c["name"] }).to eq([ "Quiet", "Waiting" ])
      expect(response.parsed_body["companies"].find { |c| c["name"] == "Waiting" }["awaiting_activation"]).to be true
    end

    it "stops counting a request once it is answered" do
      company = create(:company)
      create(:subscription, company: company)
      asked!(company, at: 1.day.ago)
      company.subscription.cancel_upgrade_request!

      get "/api/v1/admin/companies", headers: auth_headers(admin)

      expect(response.parsed_body["awaiting_count"]).to eq(0)
    end
  end

  describe "what an activation decision needs to know" do
    it "reports what the gym is actually doing with Fitora" do
      company = create(:company)
      create(:subscription, company: company)
      activity = create(:activity, company: company)
      create(:session, company: company, activity: activity, starts_at: 3.days.ago, ends_at: 3.days.ago + 1.hour)
      create(:session, company: company, activity: activity, starts_at: 90.days.ago, ends_at: 90.days.ago + 1.hour)
      create(:client, company: company)

      get "/api/v1/admin/companies/#{company.id}", headers: auth_headers(admin)

      usage = response.parsed_body["company"]["usage"]
      expect(usage["clients"]).to eq(1)
      expect(usage["activities"]).to eq(1)
      # The old session counts towards "ever", never towards the last month.
      expect(usage["sessions_last_30_days"]).to eq(1)
      expect(usage["last_session_at"]).to be_present
    end

    it "reads zero for a gym that signed up and never came back" do
      company = create(:company)
      create(:subscription, company: company)

      get "/api/v1/admin/companies/#{company.id}", headers: auth_headers(admin)

      usage = response.parsed_body["company"]["usage"]
      expect(usage.values_at("clients", "staff", "activities", "sessions_last_30_days")).to all(eq(0))
      expect(usage["last_session_at"]).to be_nil
    end
  end
  describe "recording the money arriving" do
    let(:company) { create(:company) }

    def paying!(paid_through:)
      create(:subscription, company: company, billing_period: :monthly,
                            status: :active, expires_at: nil, paid_through: paid_through)
    end

    it "moves coverage on by a period and says so in the audit log" do
      paying!(paid_through: Date.new(2026, 1, 31))

      travel_to(Date.new(2026, 2, 10)) do
        post "/api/v1/admin/companies/#{company.id}/record_payment", headers: auth_headers(admin)
      end

      expect(response).to have_http_status(:ok)
      expect(company.subscription.reload.paid_through).to eq(Date.new(2026, 2, 28))
      expect(response.parsed_body["company"]["subscription"]["current_period_paid"]).to be true
      expect(AuditLog.last.action).to eq("subscription.payment_recorded")
    end

    it "refuses a gym still on its trial — there is nothing to pay yet" do
      create(:subscription, company: company, billing_period: nil, status: :active)

      post "/api/v1/admin/companies/#{company.id}/record_payment", headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("on_trial")
    end

    it "takes a payment back that never arrived" do
      paying!(paid_through: Date.new(2026, 3, 31))

      travel_to(Date.new(2026, 3, 10)) do
        delete "/api/v1/admin/companies/#{company.id}/record_payment", headers: auth_headers(admin)
      end

      expect(company.subscription.reload.paid_through).to eq(Date.new(2026, 2, 28))
    end

    it "is closed to anyone who is not a Fitora admin" do
      paying!(paid_through: Date.current.end_of_month)
      owner = create(:user, :owner)

      post "/api/v1/admin/companies/#{company.id}/record_payment", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
