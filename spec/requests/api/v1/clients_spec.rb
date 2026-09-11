require "rails_helper"

RSpec.describe "Api::V1::Clients", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "POST /api/v1/clients" do
    it "creates a client with only first name, last name, and phone required" do
      post "/api/v1/clients", params: { client: { first_name: "Ahmed", last_name: "Ben Ali", phone: "+216 20 000 000" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["client"]["full_name"]).to eq("Ahmed Ben Ali")
    end

    it "rejects a client with no phone" do
      post "/api/v1/clients", params: { client: { first_name: "Ahmed", last_name: "Ben Ali" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "is never blocked by any client count — no plans, no limits" do
      create_list(:client, 5, company: company)

      post "/api/v1/clients", params: { client: { first_name: "Ahmed", last_name: "Ben Ali", phone: "20000000" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /api/v1/clients" do
    it "searches across name, phone, and email" do
      create(:client, company: company, first_name: "Ahmed", last_name: "Ben Ali", phone: "20111111")
      create(:client, company: company, first_name: "Leila", last_name: "Gharbi", phone: "20222222")

      get "/api/v1/clients", params: { search: "ahmed" }, headers: auth_headers(owner)

      names = response.parsed_body["clients"].map { |c| c["full_name"] }
      expect(names).to eq([ "Ahmed Ben Ali" ])
    end

    it "filters by contract_active status" do
      with_contract = create(:client, company: company)
      create(:contract, client: with_contract, company: company, status: :active, expires_at: 10.days.from_now)
      without_contract = create(:client, company: company)

      get "/api/v1/clients", params: { status: "contract_active" }, headers: auth_headers(owner)

      ids = response.parsed_body["clients"].map { |c| c["id"] }
      expect(ids).to include(with_contract.id)
      expect(ids).not_to include(without_contract.id)
    end

    it "never exposes another company's clients" do
      create(:client, company: company)
      other_org_client = create(:client)

      get "/api/v1/clients", headers: auth_headers(owner)

      ids = response.parsed_body["clients"].map { |c| c["id"] }
      expect(ids).not_to include(other_org_client.id)
    end

    it "forbids a coach from browsing the client list" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/clients", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a receptionist browse the client list" do
      receptionist = create(:staff_member, company: company, role: :receptionist)
      create(:client, company: company)

      get "/api/v1/clients", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/clients/:id" do
    it "returns the client's overview payload including outstanding balance and attendance rate" do
      client = create(:client, company: company)

      get "/api/v1/clients/#{client.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["client"]
      expect(body["outstanding_balance"].to_f).to eq(0)
      expect(body["attendance_rate"]).to be_nil
    end
  end

  describe "PATCH /api/v1/clients/:id — setting a mobile login" do
    it "lets the owner set a login for a client" do
      client = create(:client, company: company, email: "gymgoer@example.com")

      patch "/api/v1/clients/#{client.id}", params: { client: { password: "password123" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["client"]["login_enabled"]).to be true
      expect(client.reload.authenticate("password123")).to be_truthy
    end

    it "lets a receptionist set a client's login" do
      receptionist = create(:staff_member, company: company, role: :receptionist)
      client = create(:client, company: company, email: "gymgoer2@example.com")

      patch "/api/v1/clients/#{client.id}", params: { client: { password: "password123" } }, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
      expect(client.reload.login_enabled?).to be true
    end

    it "rejects enabling login without an email on file" do
      client = create(:client, company: company, email: nil)

      patch "/api/v1/clients/#{client.id}", params: { client: { password: "password123" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a too-short password" do
      client = create(:client, company: company, email: "gymgoer3@example.com")

      patch "/api/v1/clients/#{client.id}", params: { client: { password: "short" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
