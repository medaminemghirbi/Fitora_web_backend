require "rails_helper"

# A gym opening its own account confirms the address before anything past
# sign-up opens. See Api::V1::BaseController#require_confirmed_email!.
RSpec.describe "The confirmed-email gate", type: :request do
  let(:owner) { create(:user, :owner, :unverified) }

  it "shuts every owner endpoint until the link is clicked" do
    get "/api/v1/company", headers: auth_headers(owner)

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to eq("email_unverified")
  end

  # Naming the gym is where the 14 days start: they must not tick for an
  # address nobody reads.
  it "does not let the gym be named, so the trial cannot start" do
    expect {
      post "/api/v1/companies",
           params: { company: { name: "Iron Box", timezone: "Africa/Tunis", currency: "TND" } },
           headers: auth_headers(owner)
    }.not_to change(Company, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "still says who is signed in, so the screen can wait for the click" do
    get "/api/v1/auth/me", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("user", "email_verified")).to be false
  end

  it "still hydrates the shell, which routes to the waiting screen" do
    get "/api/v1/bootstrap", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
  end

  it "opens once the address is confirmed" do
    raw = owner.generate_email_verification_token!
    patch "/api/v1/email_verifications/#{raw}"

    post "/api/v1/companies",
         params: { company: { name: "Iron Box", timezone: "Africa/Tunis", currency: "TND" } },
         headers: auth_headers(owner)

    expect(response).to have_http_status(:created)
  end

  it "lets a Fitora admin impersonating the owner through" do
    create(:company, owner: owner).tap { |c| owner.update!(active_company: c) }
    admin = create(:user, :admin)
    token = JwtService.encode(owner.id, impersonator_id: admin.id)

    get "/api/v1/company", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
  end

  # Staff addresses were typed in by the gym; confirming stays informational.
  it "leaves staff alone" do
    company = create(:company)
    staff = create(:staff_member, company: company, role: :receptionist).user
    staff.update!(email_verified_at: nil)

    get "/api/v1/company", headers: auth_headers(staff)

    expect(response.parsed_body["error"]).not_to eq("email_unverified")
  end
end
