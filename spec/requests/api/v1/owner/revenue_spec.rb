require "rails_helper"

RSpec.describe "Api::V1::Owner::Revenue", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/owner/revenue" do
    it "returns today/this_week/this_month/by_day totals for the owner" do
      create(:payment, company: company, amount: 100, status: :paid, paid_at: Time.current)

      get "/api/v1/owner/revenue", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["today"].to_f).to eq(100)
      expect(body["this_week"].to_f).to eq(100)
      expect(body["this_month"].to_f).to eq(100)
      expect(body).to have_key("by_day")
    end

    it "never counts another company's payments" do
      create(:payment, company: company, amount: 50, status: :paid, paid_at: Time.current)
      other_company = create(:company)
      create(:payment, company: other_company, amount: 999, status: :paid, paid_at: Time.current)

      get "/api/v1/owner/revenue", headers: auth_headers(owner)

      expect(response.parsed_body["today"].to_f).to eq(50)
    end

    it "lets a receptionist (reports capability) view revenue" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/owner/revenue", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a coach (no reports capability) from viewing revenue" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/owner/revenue", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
