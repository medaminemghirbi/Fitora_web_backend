require "rails_helper"

RSpec.describe "Api::V1::Admin::Leads", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user, :owner) }
  let!(:lead) { create(:lead, email: "prospect@example.com", contact_name: "Amine Mghirbi", gym_name: "Power Gym", city: "Tunis") }

  describe "GET /api/v1/admin/leads" do
    it "lists every request with a count per status" do
      create(:lead, status: :converted)

      get "/api/v1/admin/leads", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["leads"].size).to eq(2)
      expect(response.parsed_body["counts"]["all"]).to eq(2)
      expect(response.parsed_body["counts"]["converted"]).to eq(1)
    end

    it "filters by status" do
      create(:lead, status: :dropped)

      get "/api/v1/admin/leads", params: { status: "dropped" }, headers: auth_headers(admin)

      expect(response.parsed_body["leads"].map { |l| l["status"] }).to eq([ "dropped" ])
    end

    it "is closed to a gym owner — this is Fitora's own funnel" do
      get "/api/v1/admin/leads", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/leads/:id" do
    it "moves the request along and records who handled it" do
      patch "/api/v1/admin/leads/#{lead.id}",
            params: { lead: { status: "contacted", internal_notes: "Rappelé le 18/09" } },
            headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(lead.reload).to be_contacted
      expect(lead.internal_notes).to eq("Rappelé le 18/09")
      expect(lead.handled_by).to eq(admin)
      expect(lead.handled_at).to be_present
    end
  end

  describe "POST /api/v1/admin/leads/:id/convert" do
    it "opens the account the gym asked for, with its owner and a first password" do
      post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(admin)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["temporary_password"]).to be_present
      expect(body["company"]["name"]).to eq("Power Gym")

      created_owner = User.find_by(email: "prospect@example.com")
      expect(created_owner).to be_owner
      company = Company.find(body["company"]["id"])
      expect(company.owner).to eq(created_owner)
      # Same setup as any other company: roles, a trial, and its one company.
      expect(company.roles).to be_any
      expect(company.subscription).to be_present
      expect(company).to be_present
      expect(created_owner.active_company).to eq(company)
      expect(lead.reload).to be_converted
      expect(lead.company).to eq(company)
    end

    it "signs the new owner in with the password it handed back" do
      post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(admin)
      password = response.parsed_body["temporary_password"]

      post "/api/v1/auth/login", params: { email: "prospect@example.com", password: password }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["account_type"]).to eq("user")
    end

    it "refuses to convert the same request twice" do
      post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(admin)

      expect { post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(admin) }
        .not_to change(Company, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses when that email is already somebody's login" do
      create(:user, email: "prospect@example.com")

      post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(admin)

      expect(response).to have_http_status(:unprocessable_content)
      expect(lead.reload).not_to be_converted
    end

    it "is closed to a gym owner" do
      post "/api/v1/admin/leads/#{lead.id}/convert", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
