require "rails_helper"

RSpec.describe "Api::V1::LibraryFolders", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "POST /api/v1/library_folders" do
    it "creates a folder" do
      post "/api/v1/library_folders", params: { library_folder: { name: "Assurances" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["folder"]["name"]).to eq("Assurances")
      expect(response.parsed_body["folder"]["document_count"]).to eq(0)
    end

    it "rejects a folder with no name" do
      post "/api/v1/library_folders", params: { library_folder: { name: "" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a duplicate folder name within the same company" do
      create(:library_folder, company: company, name: "Assurances")

      post "/api/v1/library_folders", params: { library_folder: { name: "Assurances" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows the same folder name in a different company" do
      create(:library_folder, name: "Assurances")

      post "/api/v1/library_folders", params: { library_folder: { name: "Assurances" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
    end

    it "forbids a receptionist from creating folders" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/library_folders", params: { library_folder: { name: "Assurances" } }, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a staff member whose role grants :company_library create folders" do
      staff = create(:staff_member, company: company, role: :receptionist,
                     assigned_role: create(:role, company: company, permissions: %w[company_library]))

      post "/api/v1/library_folders", params: { library_folder: { name: "Assurances" } }, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /api/v1/library_folders/:id" do
    it "returns the folder" do
      folder = create(:library_folder, company: company, name: "Assurances")

      get "/api/v1/library_folders/#{folder.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["folder"]["name"]).to eq("Assurances")
    end

    it "404s for another company's folder" do
      other_folder = create(:library_folder)

      get "/api/v1/library_folders/#{other_folder.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/library_folders" do
    it "includes each folder's document count" do
      folder = create(:library_folder, company: company, name: "Assurances")
      create_list(:library_document, 2, folder: folder)

      get "/api/v1/library_folders", headers: auth_headers(owner)

      body = response.parsed_body["folders"].find { |f| f["id"] == folder.id }
      expect(body["document_count"]).to eq(2)
    end

    it "never exposes another company's folders" do
      create(:library_folder, company: company)
      other_org_folder = create(:library_folder)

      get "/api/v1/library_folders", headers: auth_headers(owner)

      ids = response.parsed_body["folders"].map { |f| f["id"] }
      expect(ids).not_to include(other_org_folder.id)
    end
  end

  describe "PATCH /api/v1/library_folders/:id" do
    it "renames a folder" do
      folder = create(:library_folder, company: company, name: "Old name")

      patch "/api/v1/library_folders/#{folder.id}", params: { library_folder: { name: "New name" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["folder"]["name"]).to eq("New name")
    end
  end

  describe "DELETE /api/v1/library_folders/:id" do
    it "deletes a folder and its documents" do
      folder = create(:library_folder, company: company)
      document = create(:library_document, folder: folder)

      delete "/api/v1/library_folders/#{folder.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(LibraryDocument.exists?(document.id)).to be false
    end
  end
end
