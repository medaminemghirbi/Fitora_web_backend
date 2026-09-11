require "rails_helper"

RSpec.describe "Api::V1::Company mobile key", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "POST /api/v1/company/regenerate_mobile_key" do
    it "replaces the key with a new one" do
      old_key = company.mobile_auth_key

      post "/api/v1/company/regenerate_mobile_key", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      new_key = response.parsed_body["company"]["mobile_auth_key"]
      expect(new_key).not_to eq(old_key)
      expect(company.reload.mobile_auth_key).to eq(new_key)
    end

    it "forbids staff from regenerating the key" do
      staff = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/company/regenerate_mobile_key", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/company/mobile_key_qr" do
    it "returns an SVG encoding the company's key" do
      get "/api/v1/company/mobile_key_qr", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("image/svg+xml")
      expect(response.body).to include("<svg")
    end
  end

  describe "company_params does not permit setting the key directly" do
    it "ignores a mobile_auth_key sent through the general update" do
      original_key = company.mobile_auth_key

      patch "/api/v1/company", params: { company: { mobile_auth_key: "hacked123" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(company.reload.mobile_auth_key).to eq(original_key)
    end
  end
end
