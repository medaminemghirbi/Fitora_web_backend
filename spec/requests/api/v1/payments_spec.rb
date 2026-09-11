require "rails_helper"

RSpec.describe "Api::V1::Payments", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/payments" do
    it "never exposes another company's payments" do
      create(:payment, company: company, client: create(:client, company: company))
      other_company = create(:company)
      other_payment = create(:payment, company: other_company, client: create(:client, company: other_company))

      get "/api/v1/payments", headers: auth_headers(owner)

      ids = response.parsed_body["payments"].map { |p| p["id"] }
      expect(ids).not_to include(other_payment.id)
    end

    it "forbids a coach from listing payments" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/payments", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/payments/:id" do
    it "404s for a payment belonging to another company" do
      other_company = create(:company)
      other_payment = create(:payment, company: other_company, client: create(:client, company: other_company))

      get "/api/v1/payments/#{other_payment.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/payments" do
    it "rejects a client_id belonging to another company" do
      other_client = create(:client)

      post "/api/v1/payments", params: { client_id: other_client.id, amount: 50, payment_method: "cash" }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end
end
