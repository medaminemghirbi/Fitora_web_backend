require "rails_helper"

RSpec.describe "Api::V1::Owner::Dashboard", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/owner/dashboard" do
    it "returns the company and its stats for the owner" do
      get "/api/v1/owner/dashboard", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["company"]["id"]).to eq(company.id)
      expect(body["stats"]).to include("total_clients", "active_contracts", "todays_bookings", "outstanding_payments")
    end

    it "scopes stats to the current company only" do
      create(:client, company: company)
      other_company = create(:company)
      create(:client, company: other_company)

      get "/api/v1/owner/dashboard", headers: auth_headers(owner)

      expect(response.parsed_body["stats"]["total_clients"]).to eq(1)
    end

    it "lets a receptionist (reports capability) view the dashboard" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/owner/dashboard", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a coach (no reports capability) from viewing the dashboard" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/owner/dashboard", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
