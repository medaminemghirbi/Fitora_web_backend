require "rails_helper"

# Impersonation is the one way a Fitora admin reaches a gym's data, and it is
# deliberately indistinguishable from the owner's own session — that is what
# makes it useful for support. The accountability has to come from somewhere
# else: every audited action taken during such a session names the admin who
# was really at the keyboard.
RSpec.describe "Security: impersonation", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  def impersonation_headers
    post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(admin)
    { "Authorization" => "Bearer #{response.parsed_body['token']}" }
  end

  it "records who started it" do
    post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    log = company.audit_logs.find_by(action: "admin.impersonation_started")
    expect(log.metadata["admin_id"]).to eq(admin.id)
  end

  it "names the admin on an action taken during the session, not just at the start" do
    headers = impersonation_headers

    post "/api/v1/staff",
         params: { staff_member: { first_name: "Hire", last_name: "During", email: "hire@fitora.test",
                                   password: "password123", role: "receptionist" } },
         headers: headers

    expect(response).to have_http_status(:created)
    log = company.audit_logs.where.not(action: "admin.impersonation_started").last
    expect(log.metadata["impersonated_by_id"]).to eq(admin.id)
    expect(log.metadata["impersonated_by_email"]).to eq(admin.email)
  end

  it "leaves an ordinary owner action unstamped" do
    post "/api/v1/staff",
         params: { staff_member: { first_name: "Hire", last_name: "Normally", email: "hire2@fitora.test",
                                   password: "password123", role: "receptionist" } },
         headers: auth_headers(owner)

    expect(response).to have_http_status(:created)
    log = company.audit_logs.last
    expect(log.metadata).not_to have_key("impersonated_by_id")
  end

  it "cannot be started by anyone but a platform admin" do
    post "/api/v1/admin/companies/#{company.id}/impersonate", headers: auth_headers(owner)

    expect(response).to have_http_status(:forbidden)
  end
end
