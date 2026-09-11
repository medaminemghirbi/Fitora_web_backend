require "rails_helper"

RSpec.describe "Api::V1::AbsenceTypes", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/absence_types" do
    it "lists the company's absence types, ordered" do
      create(:absence_type, company: company, name: "Zeta", position: 1)
      create(:absence_type, company: company, name: "Alpha", position: 0)

      get "/api/v1/absence_types", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      names = response.parsed_body["absence_types"].map { |t| t["name"] }
      expect(names).to eq([ "Alpha", "Zeta" ])
    end

    it "never exposes another company's absence types" do
      create(:absence_type, company: company)
      other_company_type = create(:absence_type)

      get "/api/v1/absence_types", headers: auth_headers(owner)

      ids = response.parsed_body["absence_types"].map { |t| t["id"] }
      expect(ids).not_to include(other_company_type.id)
    end

    it "forbids a receptionist from browsing absence types" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/absence_types", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/absence_types" do
    it "lets the owner create an absence type" do
      post "/api/v1/absence_types", params: { absence_type: { name: "Congé sans solde", abbreviation: "CSS", paid: false } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["absence_type"]["name"]).to eq("Congé sans solde")
    end

    it "rejects an absence type with no name" do
      post "/api/v1/absence_types", params: { absence_type: { abbreviation: "XX" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids a coach from creating an absence type" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      post "/api/v1/absence_types", params: { absence_type: { name: "Congé", abbreviation: "C" } }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/absence_types/:id" do
    it "lets the owner update an absence type" do
      type = create(:absence_type, company: company, name: "Old name")

      patch "/api/v1/absence_types/#{type.id}", params: { absence_type: { name: "New name" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(type.reload.name).to eq("New name")
    end

    it "returns not found for another company's absence type" do
      other_type = create(:absence_type)

      patch "/api/v1/absence_types/#{other_type.id}", params: { absence_type: { name: "Hijacked" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/absence_types/:id" do
    it "lets the owner delete an unused absence type" do
      type = create(:absence_type, company: company)

      delete "/api/v1/absence_types/#{type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(AbsenceType.exists?(type.id)).to be false
    end

    it "blocks deletion while a leave request references it" do
      type = create(:absence_type, company: company)
      create(:leave_request, company: company, absence_type: type)

      delete "/api/v1/absence_types/#{type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(AbsenceType.exists?(type.id)).to be true
    end

    it "never lets an owner delete another company's absence type" do
      other_type = create(:absence_type)

      delete "/api/v1/absence_types/#{other_type.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
      expect(AbsenceType.exists?(other_type.id)).to be true
    end
  end
end
