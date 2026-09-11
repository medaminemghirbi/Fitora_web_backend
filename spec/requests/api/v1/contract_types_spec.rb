require "rails_helper"

RSpec.describe "Api::V1::ContractTypes", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  let(:plan_params) do
    { contract_type: { name: "Mensuel", price: 90, currency: "TND", billing_period: "monthly", unlimited_bookings: true } }
  end

  describe "GET /api/v1/contract_types" do
    it "lets a receptionist read the catalogue (needed to sign a member up)" do
      create(:contract_type, company: company)
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/contract_types", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["plans"].size).to eq(1)
    end
  end

  describe "POST /api/v1/contract_types" do
    it "lets the owner create a plan" do
      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
    end

    it "forbids a receptionist — editing the plan catalogue is configuration" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a staff member whose role grants :contract_types create a plan" do
      staff = create(:staff_member, company: company, role: :receptionist,
                     assigned_role: create(:role, company: company, permissions: %w[contracts contract_types]))

      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:created)
    end
  end
end
