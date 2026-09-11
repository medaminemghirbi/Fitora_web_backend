require "rails_helper"

RSpec.describe "Api::V1::WorkContractTypes", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/work_contract_types" do
    it "lists the company's work contract types, ordered" do
      create(:work_contract_type, company: company, name: "Zeta", position: 1)
      create(:work_contract_type, company: company, name: "Alpha", position: 0)

      get "/api/v1/work_contract_types", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["work_contract_types"].map { |t| t["name"] }
      expect(names).to eq([ "Alpha", "Zeta" ])
    end

    it "never exposes another company's work contract types" do
      create(:work_contract_type, company: company)
      other_company_type = create(:work_contract_type)

      get "/api/v1/work_contract_types", headers: auth_headers(owner)

      ids = response.parsed_body["work_contract_types"].map { |t| t["id"] }
      expect(ids).not_to include(other_company_type.id)
    end

    it "forbids a receptionist from browsing work contract types" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/work_contract_types", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/work_contract_types" do
    it "lets the owner create a work contract type" do
      post "/api/v1/work_contract_types", params: { work_contract_type: { name: "Contrat Karama", abbreviation: "KARAMA", fixed_term: true } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["work_contract_type"]["name"]).to eq("Contrat Karama")
    end

    it "rejects a work contract type with no name" do
      post "/api/v1/work_contract_types", params: { work_contract_type: { abbreviation: "XX" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids a coach from creating a work contract type" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      post "/api/v1/work_contract_types", params: { work_contract_type: { name: "CDI", abbreviation: "CDI" } }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/work_contract_types/:id" do
    it "lets the owner update a work contract type" do
      type = create(:work_contract_type, company: company, name: "Old name")

      patch "/api/v1/work_contract_types/#{type.id}", params: { work_contract_type: { name: "New name" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(type.reload.name).to eq("New name")
    end

    it "returns not found for another company's work contract type" do
      other_type = create(:work_contract_type)

      patch "/api/v1/work_contract_types/#{other_type.id}", params: { work_contract_type: { name: "Hijacked" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/work_contract_types/:id" do
    it "lets the owner delete an unused work contract type" do
      type = create(:work_contract_type, company: company)

      delete "/api/v1/work_contract_types/#{type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(WorkContractType.exists?(type.id)).to be false
    end

    it "blocks deletion while a work contract references it" do
      type = create(:work_contract_type, company: company)
      create(:work_contract, company: company, work_contract_type: type)

      delete "/api/v1/work_contract_types/#{type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(WorkContractType.exists?(type.id)).to be true
    end

    it "never lets an owner delete another company's work contract type" do
      other_type = create(:work_contract_type)

      delete "/api/v1/work_contract_types/#{other_type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
      expect(WorkContractType.exists?(other_type.id)).to be true
    end
  end
end
