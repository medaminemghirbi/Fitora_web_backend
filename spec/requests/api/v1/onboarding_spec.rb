require "rails_helper"

RSpec.describe "Api::V1::Onboarding", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "POST /api/v1/onboarding/dismiss" do
    it "stamps setup_dismissed_at and returns the updated setup state" do
      post "/api/v1/onboarding/dismiss", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["setup"]).to include("dismissed" => true)
      expect(company.reload.setup_dismissed_at).to be_present
    end

    it "forbids staff from dismissing the guide" do
      staff = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/onboarding/dismiss", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
      expect(company.reload.setup_dismissed_at).to be_nil
    end
  end

  describe "Company#setup_state" do
    it "flips each flag as the underlying data is created" do
      expect(company.setup_state).to include(
        activity: false, contract_type: false, coach: false, complete: false
      )

      create(:activity, location: company.location)
      create(:contract_type, company: company)
      create(:coach, company: company)

      expect(company.reload.setup_state).to include(
        activity: true, contract_type: true, coach: true, complete: true
      )
    end
  end
end
