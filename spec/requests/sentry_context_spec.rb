require "rails_helper"

# ApplicationController#tag_sentry_context! runs on every authenticated
# request already (see rack_attack_spec.rb-style "doesn't crash" coverage
# implicit in the whole suite passing) — this spec checks the actual values
# it hands Sentry, not just that nothing raises.
RSpec.describe "Sentry request context", type: :request do
  it "tags a staff/owner login with their company and role" do
    owner = create(:user, :owner)
    company = create(:company, owner: owner)

    expect(Sentry).to receive(:set_user).with(id: owner.id, email: owner.email)
    expect(Sentry).to receive(:set_tags).with(account_type: "user", role: "owner", company_id: company.id)

    get "/api/v1/auth/me", headers: auth_headers(owner)
  end

  it "tags a client login with their own id, never a user role or a single gym" do
    client = create(:client, password: "password123")

    expect(Sentry).to receive(:set_user).with(id: client.id, email: client.email)
    expect(Sentry).to receive(:set_tags).with(account_type: "client")

    get "/api/v1/auth/me", headers: auth_headers(client)
  end

  it "never raises for a platform admin, who has no company" do
    admin = create(:user, :admin)

    get "/api/v1/auth/me", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
  end
end
