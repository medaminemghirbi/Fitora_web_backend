require "rails_helper"

RSpec.describe "Api::V1::Pairing", type: :request do
  describe "GET /api/v1/pairing/:mobile_auth_key" do
    it "resolves a company's branding from its pairing key, with no authentication" do
      company = create(:company, name: "Power Gym", primary_color: "#e11d48")

      get "/api/v1/pairing/#{company.mobile_auth_key}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["branding"]["name"]).to eq("Power Gym")
      expect(response.parsed_body["branding"]["primary_color"]).to eq("#e11d48")
    end

    it "is case-insensitive" do
      company = create(:company, mobile_auth_key: "abcd1234")

      get "/api/v1/pairing/ABCD1234"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["branding"]["name"]).to eq(company.name)
    end

    it "404s for an unknown key" do
      get "/api/v1/pairing/doesnotexist"

      expect(response).to have_http_status(:not_found)
    end
  end
end
