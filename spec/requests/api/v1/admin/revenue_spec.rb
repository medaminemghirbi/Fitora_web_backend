require "rails_helper"

RSpec.describe "Api::V1::Admin::Revenue", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:company) { create(:company, admin: admin) }

  describe "GET /api/v1/admin/revenue" do
    it "returns today/this_week/this_month/by_day totals for the admin" do
      create(:payment, company: company, amount: 100, status: :paid, paid_at: Time.current)

      get "/api/v1/admin/revenue", headers: auth_headers(admin)

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

      get "/api/v1/admin/revenue", headers: auth_headers(admin)

      expect(response.parsed_body["today"].to_f).to eq(50)
    end

    it "forbids a moderator: taking money at the desk is not reading what the gym earns" do
      moderator = create(:staff_member, company: company, role: :moderator)

      get "/api/v1/admin/revenue", headers: auth_headers(moderator.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a role the admin granted 'revenue' through" do
      accountant = create(:role, company: company, key: "comptable", name: "Comptable", permissions: %w[reports revenue])
      staff = create(:staff_member, company: company, role: :moderator, assigned_role: accountant)

      get "/api/v1/admin/revenue", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a coach (no reports capability) from viewing revenue" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/admin/revenue", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
