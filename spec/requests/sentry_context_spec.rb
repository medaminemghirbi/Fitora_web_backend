require "rails_helper"

# ApplicationController#tag_sentry_context! runs on every authenticated
# request already (see rack_attack_spec.rb-style "doesn't crash" coverage
# implicit in the whole suite passing) — this spec checks the actual values
# it hands Sentry, not just that nothing raises.
RSpec.describe "Sentry request context", type: :request do
  it "tags a staff/admin login with their company and role" do
    admin = create(:user, :admin)
    company = create(:company, admin: admin)

    expect(Sentry).to receive(:set_user).with(id: admin.id, email: admin.email)
    expect(Sentry).to receive(:set_tags).with(account_type: "user", role: "admin", company_id: company.id)

    get "/api/v1/auth/me", headers: auth_headers(admin)
  end

  it "never raises for a platform superadmin, who has no company" do
    superadmin = create(:user, :superadmin)

    get "/api/v1/auth/me", headers: auth_headers(superadmin)

    expect(response).to have_http_status(:ok)
  end
end
