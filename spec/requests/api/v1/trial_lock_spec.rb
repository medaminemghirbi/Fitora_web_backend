require "rails_helper"

RSpec.describe "Free trial lock", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "an company still within its trial (or with no deadline at all)" do
    it "is never blocked" do
      create(:subscription, company: company, expires_at: 3.days.from_now)

      get "/api/v1/clients", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
    end

    it "with no expires_at at all is never blocked" do
      create(:subscription, company: company, expires_at: nil)

      get "/api/v1/clients", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "an company whose trial has expired" do
    let!(:subscription) { create(:subscription, company: company, expires_at: 1.day.ago) }

    it "locks the owner out of ordinary org-scoped endpoints" do
      get "/api/v1/clients", headers: auth_headers(owner)

      expect(response).to have_http_status(:payment_required)
      expect(response.parsed_body["error"]).to eq("trial_expired")
    end

    it "still lets the owner see their own subscription status" do
      get "/api/v1/subscription", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["locked"]).to be true
    end

    it "still lets the owner see their company profile" do
      get "/api/v1/company", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
    end

    it "blocks the owner from editing the company profile" do
      patch "/api/v1/company", params: { company: { name: "New Name" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:payment_required)
    end

    it "locks out staff entirely, with no exceptions" do
      staff = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/subscription", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:payment_required)
    end

    it "never blocks the platform admin" do
      admin = create(:user, :admin)

      get "/api/v1/admin/companies", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
    end

    it "is lifted once a platform admin grants access" do
      admin = create(:user, :admin)

      patch "/api/v1/admin/companies/#{company.id}/subscription",
            params: { status: "active" },
            headers: auth_headers(admin)

      expect(subscription.reload.expires_at).to be_nil
      expect(subscription.locked?).to be false

      get "/api/v1/clients", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "a company whose subscription status is set to anything but active" do
    %i[inactive expired cancelled].each do |status|
      it "locks all staff out even with no expires_at deadline (status: #{status})" do
        subscription = create(:subscription, company: company, status: status, expires_at: nil)
        coach = create(:staff_member, company: company, role: :coach)
        staff2 = create(:staff_member, company: company, role: :receptionist)

        expect(subscription.locked?).to be true

        get "/api/v1/clients", headers: auth_headers(coach.user)
        expect(response).to have_http_status(:payment_required)

        get "/api/v1/clients", headers: auth_headers(staff2.user)
        expect(response).to have_http_status(:payment_required)
      end
    end
  end
end
