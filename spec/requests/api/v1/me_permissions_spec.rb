require "rails_helper"

RSpec.describe "Api::V1 GET /api/v1/me/permissions", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  it "gives the owner every permission" do
    get "/api/v1/me/permissions", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["role"]["key"]).to eq("owner")
    expect(body["permissions"]).to match_array(ModuleCatalog.permissions_for(company.enabled_module_keys))
  end

  it "returns a staff login's resolved role permissions" do
    staff = create(:staff_member, company: company, role: :receptionist)

    get "/api/v1/me/permissions", headers: auth_headers(staff.user)

    body = response.parsed_body
    expect(body["role"]["key"]).to eq("receptionist")
    expect(body["permissions"]).to include("bookings", "payments", "sessions")
    expect(body["permissions"]).not_to include("contract_types")
  end

  it "reflects a re-permissioned built-in role" do
    staff = create(:staff_member, company: company, role: :coach)
    company.roles.find_by(key: "coach").update!(permissions: %w[checkin bookings clients])

    get "/api/v1/me/permissions", headers: auth_headers(staff.user)

    expect(response.parsed_body["permissions"]).to match_array(%w[clients bookings checkin])
  end

  it "gives a platform admin no company permissions" do
    admin = create(:user, :admin)

    get "/api/v1/me/permissions", headers: auth_headers(admin)

    expect(response.parsed_body).to eq("role" => nil, "permissions" => [])
  end

  it "401s without a token" do
    get "/api/v1/me/permissions"
    expect(response).to have_http_status(:unauthorized)
  end
end
