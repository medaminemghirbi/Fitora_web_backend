require "rails_helper"

RSpec.describe "Api::V1::DataExchange", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  def upload(csv_body)
    Rack::Test::UploadedFile.new(StringIO.new(csv_body), "text/csv", original_filename: "import.csv")
  end

  describe "GET template" do
    it "returns a CSV template with headers and an example row, for a known entity" do
      get "/api/v1/data_exchange/clients/template", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      rows = CSV.parse(response.body)
      expect(rows.first).to eq(%w[first_name last_name email phone])
      expect(rows.size).to eq(2)
    end

    it "404s for an unknown entity" do
      get "/api/v1/data_exchange/spaceships/template", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "forbids a staff member without the matching capability" do
      staff = create(:staff_member, company: company, role: :receptionist,
                     assigned_role: create(:role, company: company, permissions: []))

      get "/api/v1/data_exchange/clients/template", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET export" do
    it "exports the company's clients as CSV" do
      create(:client, company: company, first_name: "Rania", last_name: "Ferjani", email: "rania@example.com", phone: "+21620000001")

      get "/api/v1/data_exchange/clients/export", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      rows = CSV.parse(response.body, headers: true)
      expect(rows.first["email"]).to eq("rania@example.com")
    end

    it "exports the company's activities as CSV" do
      create(:activity, location: company.locations.first, name: "Yoga")

      get "/api/v1/data_exchange/activities/export", headers: auth_headers(owner)

      rows = CSV.parse(response.body, headers: true)
      expect(rows.first["name"]).to eq("Yoga")
    end

    it "exports the company's contracts as CSV" do
      client = create(:client, company: company)
      contract_type = create(:contract_type, company: company, name: "Mensuel")
      create(:contract, client: client, contract_type: contract_type, company: company)

      get "/api/v1/data_exchange/contracts/export", headers: auth_headers(owner)

      rows = CSV.parse(response.body, headers: true)
      expect(rows.first["client_email"]).to eq(client.email)
      expect(rows.first["contract_type_name"]).to eq("Mensuel")
    end

    it "exports the company's payments as CSV" do
      client = create(:client, company: company)
      period = create(:contract_period, contract: create(:contract, client: client, company: company))
      create(:payment, client: client, company: company, contract_period: period, amount: 90)

      get "/api/v1/data_exchange/payments/export", headers: auth_headers(owner)

      rows = CSV.parse(response.body, headers: true)
      expect(rows.first["client_email"]).to eq(client.email)
      expect(rows.first["amount"].to_f).to eq(90.0)
    end
  end

  describe "POST import" do
    context "clients" do
      it "creates clients from valid rows and reports invalid ones" do
        csv = <<~CSV
          first_name,last_name,email,phone
          Rania,Ferjani,rania@example.com,+21620000001
          ,MissingFirstName,bad@example.com,+21620000002
        CSV

        post "/api/v1/data_exchange/clients/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["created"]).to eq(1)
        expect(body["errors"].size).to eq(1)
        expect(body["errors"].first["row"]).to eq(3)
        expect(company.clients.find_by(email: "rania@example.com")).to be_present
      end

      it "requires a file" do
        post "/api/v1/data_exchange/clients/import", headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "activities" do
      it "creates an activity for the company's location" do
        csv = "name,session_format,duration_minutes,capacity,emoji,description\nYoga,collective,60,20,🧘,\n"

        post "/api/v1/data_exchange/activities/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        expect(response.parsed_body["created"]).to eq(1)
        expect(company.locations.first.activities.find_by(name: "Yoga")).to be_present
      end
    end

    context "contracts" do
      it "creates a contract when the client and plan both exist" do
        client = create(:client, company: company, email: "amine@example.com")
        create(:contract_type, company: company, name: "Abonnement mensuel")
        csv = "client_email,contract_type_name,starts_at\namine@example.com,Abonnement mensuel,2026-01-01\n"

        post "/api/v1/data_exchange/contracts/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        expect(response.parsed_body["created"]).to eq(1)
        expect(client.contracts.count).to eq(1)
      end

      it "reports a row whose client email doesn't exist" do
        create(:contract_type, company: company, name: "Abonnement mensuel")
        csv = "client_email,contract_type_name,starts_at\nghost@example.com,Abonnement mensuel,2026-01-01\n"

        post "/api/v1/data_exchange/contracts/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["created"]).to eq(0)
        expect(body["errors"].first["message"]).to include("ghost@example.com")
      end
    end

    context "payments" do
      it "records a payment against the client's current contract period" do
        client = create(:client, company: company, email: "amine@example.com")
        create(:contract_period, contract: create(:contract, client: client, company: company))
        csv = "client_email,amount,payment_method,paid_at\namine@example.com,90,cash,2026-01-01\n"

        post "/api/v1/data_exchange/payments/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        expect(response.parsed_body["created"]).to eq(1)
        expect(client.payments.count).to eq(1)
      end

      it "reports a row for a client with no active contract" do
        create(:client, company: company, email: "amine@example.com")
        csv = "client_email,amount,payment_method,paid_at\namine@example.com,90,cash,2026-01-01\n"

        post "/api/v1/data_exchange/payments/import", params: { file: upload(csv) }, headers: auth_headers(owner)

        body = response.parsed_body
        expect(body["created"]).to eq(0)
        expect(body["errors"].first["message"]).to include("no active contract")
      end
    end
  end
end
