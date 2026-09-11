require "rails_helper"

RSpec.describe "Api::V1::AppUpdates", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "authorization" do
    it "forbids staff" do
      staff = create(:staff_member, company: company)

      get "/api/v1/app_updates", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/app_updates" do
    it "lists updates newest first, read-only" do
      create(:app_update, version: "1.0.0", published_at: 2.days.ago)
      create(:app_update, version: "1.1.0", published_at: 1.day.ago)

      get "/api/v1/app_updates", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      versions = response.parsed_body["app_updates"].map { |u| u["version"] }
      expect(versions).to eq([ "1.1.0", "1.0.0" ])
    end
  end
end
