require "rails_helper"

RSpec.describe "Api::V1 GET /api/v1/bootstrap", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let!(:subscription) { create(:subscription, company: company, expires_at: 5.days.from_now) }

  it "hydrates the owner shell in one call" do
    get "/api/v1/bootstrap", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["user"]["id"]).to eq(owner.id)
    expect(body["company"]["id"]).to eq(company.id)
    expect(body["branding"]["name"]).to eq(company.name)
    expect(body["role"]["key"]).to eq("owner")
    expect(body["permissions"]).to match_array(ModuleCatalog::ALL_PERMISSIONS)
    expect(body["modules"]).to match_array(company.enabled_module_keys)
    expect(body["modules"]).to include("base", "clients", "classes", "ged", "payroll", "suppliers")
    expect(body["roles"].map { |r| r["key"] }).to match_array(Role::SYSTEM_KEYS)
    expect(body["roles"].first).to include("id", "permissions", "builtin")
    expect(body["permission_catalog"]).to include("contract_types")
    expect(body["subscription"]).to include("status", "locked", "trial_days_remaining")
    expect(body["setup"]).to include(
      "activity" => false, "contract_type" => false, "coach" => false,
      "work_contract" => false, "dismissed" => false, "complete" => false
    )
    expect(body["notifications"]).to eq("unread_count" => 0)
  end

  it "omits the setup checklist for staff" do
    staff = create(:staff_member, company: company, role: :receptionist)

    get "/api/v1/bootstrap", headers: auth_headers(staff.user)

    expect(response.parsed_body["setup"]).to be_nil
  end

  it "hides the full company profile from staff but still returns branding" do
    staff = create(:staff_member, company: company, role: :receptionist)

    get "/api/v1/bootstrap", headers: auth_headers(staff.user)

    body = response.parsed_body
    expect(body["company"]).to be_nil
    expect(body["branding"]["name"]).to eq(company.name)
    # every member's shell reads the tenant language + currency from branding
    expect(body["branding"]).to include("locale" => company.locale, "currency" => "TND", "currency_symbol" => "DT")
    expect(body["permissions"]).to include("bookings")
  end

  it "gives the owner every feature and every permission — nothing is gated" do
    get "/api/v1/bootstrap", headers: auth_headers(owner)

    body = response.parsed_body
    expect(body["modules"]).to match_array(%w[base] + ModuleCatalog::KEYS)
    expect(body["permissions"]).to include(
      "clients", "payments", "sessions", "contracts", "bookings", "company_library", "coaches"
    )
  end

  it "still bootstraps a locked company (for the trial-expired screen)" do
    subscription.update!(status: :active, expires_at: 2.days.ago)

    get "/api/v1/bootstrap", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["subscription"]["locked"]).to be(true)
  end
end
