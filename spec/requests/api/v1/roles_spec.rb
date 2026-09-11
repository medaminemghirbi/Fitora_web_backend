require "rails_helper"

RSpec.describe "Api::V1::Roles", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/roles" do
    it "returns the company's roles plus the permission catalogue" do
      get "/api/v1/roles", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["roles"].map { |r| r["key"] }).to match_array(Role::SYSTEM_KEYS)
      expect(body["permission_catalog"]).to include("contract_types", "sessions")
      owner_row = body["roles"].find { |r| r["key"] == "owner" }
      expect(owner_row["builtin"]).to be true
      expect(owner_row["deletable"]).to be false
    end

    it "forbids a non-owner staff member" do
      staff = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/roles", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/roles" do
    it "creates a custom role, slugifying the key and sanitising permissions" do
      post "/api/v1/roles",
           params: { role: { name: "Comptable", permissions: %w[payments reports bogus] } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      role = response.parsed_body["role"]
      expect(role["key"]).to eq("comptable")
      expect(role["builtin"]).to be false
      expect(role["permissions"]).to match_array(%w[payments reports])
    end
  end

  describe "PATCH /api/v1/roles/:id" do
    it "re-permissions a built-in role" do
      receptionist = company.roles.find_by(key: "receptionist")

      patch "/api/v1/roles/#{receptionist.id}",
            params: { role: { permissions: %w[sessions bookings clients contracts payments checkin reports contract_types] } },
            headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(receptionist.reload.permissions).to include("contract_types")
    end

    it "refuses to edit the owner role" do
      owner_role = company.roles.find_by(key: "owner")

      patch "/api/v1/roles/#{owner_role.id}", params: { role: { name: "Boss" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE /api/v1/roles/:id" do
    it "deletes an unused custom role" do
      role = create(:role, company: company)

      delete "/api/v1/roles/#{role.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(Role.exists?(role.id)).to be false
    end

    it "refuses to delete a built-in role" do
      receptionist = company.roles.find_by(key: "receptionist")

      delete "/api/v1/roles/#{receptionist.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses to delete a role still assigned to staff" do
      role = create(:role, company: company)
      create(:staff_member, company: company, role: :receptionist, assigned_role: role)

      delete "/api/v1/roles/#{role.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
