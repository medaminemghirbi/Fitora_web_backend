require "rails_helper"

RSpec.describe "Api::V1::Companies", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/company" do
    it "returns the owner's company" do
      get "/api/v1/company", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["company"]["id"]).to eq(company.id)
    end

    it "forbids staff from reading company settings" do
      staff = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/company", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/companies — signup" do
    let(:fresh_owner) { create(:user, :owner) }

    it "gives the new company every feature" do
      post "/api/v1/companies",
           params: { company: { name: "Iron Box", timezone: "Africa/Tunis", currency: "TND" } },
           headers: auth_headers(fresh_owner)

      expect(response).to have_http_status(:created)
      created = Company.find_by(owner: fresh_owner)
      expect(created.enabled_module_keys).to match_array(%w[base] + ModuleCatalog::KEYS)
    end

    it "becomes the owner's active company immediately" do
      post "/api/v1/companies", params: { company: { name: "Iron Box", timezone: "Africa/Tunis", currency: "TND" } },
                                 headers: auth_headers(fresh_owner)

      created = Company.find_by(owner: fresh_owner)
      expect(fresh_owner.reload.active_company).to eq(created)
    end

    it "lets an owner already on the unlimited tier create as many companies as they like" do
      owner.update!(company_limit: nil)

      post "/api/v1/companies", params: { company: { name: "Second Gym", timezone: "Africa/Tunis", currency: "TND" } },
                                 headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(owner.companies.count).to eq(2)
    end

    it "blocks a second company once the owner's tier limit (1) is reached" do
      post "/api/v1/companies", params: { company: { name: "Second Gym", timezone: "Africa/Tunis", currency: "TND" } },
                                 headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("company_limit_reached")
      expect(owner.companies.count).to eq(1)
    end

    it "allows a third company on the tier-3 plan, then blocks a fourth" do
      owner.update!(company_limit: 3)
      create(:company, owner: owner)

      post "/api/v1/companies", params: { company: { name: "Third Gym", timezone: "Africa/Tunis", currency: "TND" } },
                                 headers: auth_headers(owner)
      expect(response).to have_http_status(:created)

      post "/api/v1/companies", params: { company: { name: "Fourth Gym", timezone: "Africa/Tunis", currency: "TND" } },
                                 headers: auth_headers(owner)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/companies" do
    it "lists every company this owner runs, flagging which one is active" do
      owner.update!(company_limit: nil)
      second = create(:company, owner: owner)

      get "/api/v1/companies", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["companies"]
      expect(body.map { |c| c["id"] }).to contain_exactly(company.id, second.id)
      expect(body.find { |c| c["id"] == company.id }["active"]).to be true
      expect(body.find { |c| c["id"] == second.id }["active"]).to be false
    end

    it "never lists another owner's companies" do
      other = create(:company)

      get "/api/v1/companies", headers: auth_headers(owner)

      ids = response.parsed_body["companies"].map { |c| c["id"] }
      expect(ids).not_to include(other.id)
    end
  end

  describe "POST /api/v1/companies/:id/switch" do
    it "moves the owner's active company and current_company follows on the next request" do
      owner.update!(company_limit: nil)
      second = create(:company, owner: owner)

      post "/api/v1/companies/#{second.id}/switch", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["company"]["id"]).to eq(second.id)

      get "/api/v1/company", headers: auth_headers(owner)
      expect(response.parsed_body["company"]["id"]).to eq(second.id)
    end

    it "404s when switching to a company this owner doesn't own" do
      other = create(:company)

      post "/api/v1/companies/#{other.id}/switch", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "is unaffected by another of the owner's companies being trial-locked" do
      owner.update!(company_limit: nil)
      second = create(:company, owner: owner)
      create(:subscription, company: company, expires_at: 1.day.ago)

      post "/api/v1/companies/#{second.id}/switch", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/company — subscription info" do
    it "lists every feature as included and the monthly / annual price in the company's currency" do
      SubscriptionPrice.for("TND", company_limit: 1).update!(monthly_cents: 20_000)
      get "/api/v1/company", headers: auth_headers(owner)
      body = response.parsed_body["company"]

      expect(body["included_modules"]).to match_array(ModuleCatalog::KEYS)
      expect(body["monthly_subscription_cents"]).to eq(20_000)
      # 12 months minus the 10% default annual discount
      expect(body["annual_subscription_cents"]).to eq((20_000 * 12 * 0.9).round)
      expect(body["annual_discount_percent"]).to eq(10)
    end

    it "prices in the company's own currency, auto-seeded from the TND reference" do
      SubscriptionPrice.for("TND", company_limit: 1).update!(monthly_cents: 18_000)
      company.update!(currency: "EUR")

      get "/api/v1/company", headers: auth_headers(owner)

      expect(response.parsed_body["company"]["monthly_subscription_cents"]).to eq(18_000)
      expect(SubscriptionPrice.for("EUR", company_limit: 1).monthly_cents).to eq(18_000)
    end
  end

  describe "PATCH /api/v1/company — branding" do
    it "sets a slug and a primary color" do
      patch "/api/v1/company", params: { company: { slug: "power-gym", primary_color: "#ff5500" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["company"]
      expect(body["slug"]).to eq("power-gym")
      expect(body["primary_color"]).to eq("#ff5500")
    end

    it "uploads a logo" do
      patch "/api/v1/company", params: { company: { logo: fixture_file_upload("sample.png", "image/png") } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["company"]["logo_url"]).to be_present
    end

    it "rejects an invalid hex color" do
      patch "/api/v1/company", params: { company: { primary_color: "orange" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a slug with uppercase or spaces" do
      patch "/api/v1/company", params: { company: { slug: "Power Gym" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a slug already used by another company" do
      create(:company, slug: "power-gym")

      patch "/api/v1/company", params: { company: { slug: "power-gym" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "defaults working_days to Monday–Friday" do
      get "/api/v1/company", headers: auth_headers(owner)

      expect(response.parsed_body["company"]["working_days"]).to eq([ 1, 2, 3, 4, 5 ])
    end

    it "updates working_days (a Saturday-opening gym)" do
      patch "/api/v1/company", params: { company: { working_days: [ 6, 1, 2, 3, 4 ] } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["company"]["working_days"]).to eq([ 1, 2, 3, 4, 6 ])
      expect(company.reload.working_days).to eq([ 1, 2, 3, 4, 6 ])
    end

    it "rejects an empty working_days list" do
      patch "/api/v1/company", params: { company: { working_days: [ "" ] } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an out-of-range weekday" do
      patch "/api/v1/company", params: { company: { working_days: [ 1, 2, 7 ] } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids staff from changing branding" do
      staff = create(:staff_member, company: company, role: :receptionist)

      patch "/api/v1/company", params: { company: { primary_color: "#ff5500" } }, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
      expect(company.reload.primary_color).to be_nil
    end
  end
end
