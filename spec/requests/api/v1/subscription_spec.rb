require "rails_helper"

RSpec.describe "Api::V1::Subscription", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/subscription" do
    it "reports the company's status and trial countdown" do
      create(:subscription, company: company, status: :active, starts_at: 1.day.ago, expires_at: 13.days.from_now)

      get "/api/v1/subscription", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body["subscription"]
      expect(json["status"]).to eq("active")
      expect(response.parsed_body["trial_days_remaining"]).to eq(13)
      expect(response.parsed_body["locked"]).to be false
    end

    it "forbids staff — this is the owner's own account status" do
      staff = create(:staff_member, company: company)

      get "/api/v1/subscription", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "reports on_trial until a billing period is set" do
      sub = create(:subscription, company: company, status: :active, starts_at: 1.day.ago, expires_at: 10.days.from_now)

      get "/api/v1/subscription", headers: auth_headers(owner)
      expect(response.parsed_body["on_trial"]).to be true

      sub.update!(billing_period: :monthly)
      get "/api/v1/subscription", headers: auth_headers(owner)
      expect(response.parsed_body["on_trial"]).to be false
      expect(response.parsed_body["subscription"]["billing_period"]).to eq("monthly")
    end
  end

  describe "POST /api/v1/subscription/request_upgrade" do
    let!(:subscription) { create(:subscription, company: company, status: :active, starts_at: 1.day.ago, expires_at: 10.days.from_now) }

    it "records the owner's activation request and preferred period" do
      post "/api/v1/subscription/request_upgrade", params: { period: "yearly" }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["subscription"]
      expect(body["upgrade_requested_at"]).to be_present
      expect(body["upgrade_requested_period"]).to eq("yearly")
      expect(subscription.reload.upgrade_requested?).to be true
    end

    it "ignores an unknown period" do
      post "/api/v1/subscription/request_upgrade", params: { period: "weekly" }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["subscription"]["upgrade_requested_period"]).to be_nil
      expect(subscription.reload.upgrade_requested?).to be true
    end

    it "can be cancelled" do
      subscription.request_upgrade!(period: "monthly")

      delete "/api/v1/subscription/request_upgrade", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(subscription.reload.upgrade_requested?).to be false
    end

    it "is owner-only" do
      staff = create(:staff_member, company: company)
      post "/api/v1/subscription/request_upgrade", headers: auth_headers(staff.user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
