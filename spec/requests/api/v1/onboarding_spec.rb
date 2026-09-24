require "rails_helper"

RSpec.describe "Api::V1::Onboarding", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:company) { create(:company, admin: admin) }

  def state
    get "/api/v1/onboarding", headers: auth_headers(admin)
    response.parsed_body["onboarding"]
  end

  describe "GET /api/v1/onboarding" do
    it "starts on the company step with nothing done" do
      expect(state).to include("step" => "company", "complete" => false, "dismissed" => false, "done_count" => 0)
    end

    it "omits the spaces step until the company turns rooms on" do
      expect(state["steps"].map { |s| s["key"] }).to eq(%w[company activities plans staff])

      company.update!(settings: { features: { spaces: true } })

      expect(state["steps"].map { |s| s["key"] }).to eq(%w[company activities spaces plans staff])
    end

    it "ticks a step off when its data is created anywhere in the app" do
      create(:activity, company: company)

      activities = state["steps"].find { |s| s["key"] == "activities" }
      expect(activities).to include("state" => "done", "count" => 1)
    end

    it "asks for the first step that is neither done nor skipped" do
      create(:activity, company: company)
      patch "/api/v1/onboarding", params: { step: "company" }, headers: auth_headers(admin)

      expect(state["step"]).to eq("plans")
    end

    it "forbids staff" do
      staff = create(:staff_member, company: company, role: :moderator)

      get "/api/v1/onboarding", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/onboarding" do
    it "marks a step done and survives a reload" do
      patch "/api/v1/onboarding", params: { step: "company" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(company.reload.settings.onboarding[:completed]).to eq(%w[company])
      expect(state["steps"].find { |s| s["key"] == "company" }["state"]).to eq("done")
    end

    it "clears a previous skip of the same step" do
      post "/api/v1/onboarding/skip", params: { step: "staff" }, headers: auth_headers(admin)
      patch "/api/v1/onboarding", params: { step: "staff" }, headers: auth_headers(admin)

      settings = company.reload.settings.onboarding
      expect(settings[:completed]).to eq(%w[staff])
      expect(settings[:skipped]).to be_empty
    end

    it "rejects a step that is not in the catalogue" do
      patch "/api/v1/onboarding", params: { step: "billing" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(company.reload.settings.onboarding[:completed]).to be_empty
    end

    it "forbids staff" do
      staff = create(:staff_member, company: company, role: :moderator)

      patch "/api/v1/onboarding", params: { step: "company" }, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
      expect(company.reload.settings.onboarding[:completed]).to be_empty
    end
  end

  describe "POST /api/v1/onboarding/skip" do
    it "skips an optional step" do
      post "/api/v1/onboarding/skip", params: { step: "staff" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(state["steps"].find { |s| s["key"] == "staff" }["state"]).to eq("skipped")
    end

    it "refuses to skip a step the business cannot run without" do
      post "/api/v1/onboarding/skip", params: { step: "plans" }, headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(company.reload.settings.onboarding[:skipped]).to be_empty
    end
  end

  describe "POST /api/v1/onboarding/dismiss" do
    it "stops the app asking without pretending the steps are done" do
      post "/api/v1/onboarding/dismiss", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["onboarding"]).to include("dismissed" => true, "complete" => false)
      expect(company.reload.setup_dismissed_at).to be_present
    end

    it "forbids staff from dismissing the flow" do
      staff = create(:staff_member, company: company, role: :moderator)

      post "/api/v1/onboarding/dismiss", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
      expect(company.reload.setup_dismissed_at).to be_nil
    end
  end

  describe "completion" do
    it "is complete once every applicable step is done or skipped" do
      create(:activity, company: company)
      create(:contract_type, company: company)
      patch "/api/v1/onboarding", params: { step: "company" }, headers: auth_headers(admin)
      post "/api/v1/onboarding/skip", params: { step: "staff" }, headers: auth_headers(admin)

      expect(state).to include("complete" => true, "step" => "done")
    end

    it "is incomplete again when turning rooms on adds a step" do
      create(:activity, company: company)
      create(:contract_type, company: company)
      patch "/api/v1/onboarding", params: { step: "company" }, headers: auth_headers(admin)
      post "/api/v1/onboarding/skip", params: { step: "staff" }, headers: auth_headers(admin)
      # reload first: `settings=` is read-modify-write on one jsonb column,
      # so writing from a copy loaded before the requests would take the
      # flow's own progress back out again.
      company.reload.update!(settings: { features: { spaces: true } })

      expect(state).to include("complete" => false, "step" => "spaces")
    end
  end
end
