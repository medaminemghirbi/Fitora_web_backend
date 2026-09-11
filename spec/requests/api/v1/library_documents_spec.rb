require "rails_helper"

RSpec.describe "Api::V1::LibraryDocuments", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let!(:folder) { create(:library_folder, company: company, name: "Assurances") }
  let(:sample_file) { fixture_file_upload("sample.png", "image/png") }

  describe "POST /api/v1/library_documents" do
    it "creates a document with a title, a folder, and an attached file" do
      post "/api/v1/library_documents",
           params: { library_document: { title: "Attestation d'assurance", folder_id: folder.id, file: sample_file } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["document"]
      expect(body["title"]).to eq("Attestation d'assurance")
      expect(body["folder_id"]).to eq(folder.id)
      expect(body["file"]["content_type"]).to eq("image/png")
      expect(body["file"]["url"]).to be_present
      expect(body["created_by"]["full_name"]).to eq(owner.full_name)
    end

    it "rejects a document with no title" do
      post "/api/v1/library_documents", params: { library_document: { folder_id: folder.id, file: sample_file } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a document with no folder" do
      post "/api/v1/library_documents", params: { library_document: { title: "Test", file: sample_file } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a document with no file" do
      post "/api/v1/library_documents", params: { library_document: { title: "Test", folder_id: folder.id } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("File must be attached")
    end

    it "rejects a file that isn't a PDF or an image" do
      Tempfile.create([ "notes", ".txt" ]) do |tmp|
        tmp.write("just text")
        tmp.rewind
        upload = Rack::Test::UploadedFile.new(tmp.path, "text/plain", original_filename: "notes.txt")

        post "/api/v1/library_documents", params: { library_document: { title: "Test", folder_id: folder.id, file: upload } }, headers: auth_headers(owner)
      end

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a folder that belongs to another company" do
      other_folder = create(:library_folder)

      post "/api/v1/library_documents", params: { library_document: { title: "Test", folder_id: other_folder.id, file: sample_file } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "forbids a coach from adding documents" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      post "/api/v1/library_documents", params: { library_document: { title: "Test", folder_id: folder.id, file: sample_file } }, headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a staff member whose role grants :company_library add documents" do
      staff = create(:staff_member, company: company, role: :receptionist,
                     assigned_role: create(:role, company: company, permissions: %w[company_library]))

      post "/api/v1/library_documents", params: { library_document: { title: "Test", folder_id: folder.id, file: sample_file } }, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:created)
    end
  end

  describe "GET /api/v1/library_documents" do
    it "filters by folder" do
      other_folder = create(:library_folder, company: company, name: "Juridique")
      create(:library_document, folder: folder, title: "Assurance RC")
      create(:library_document, folder: other_folder, title: "Statuts")

      get "/api/v1/library_documents", params: { folder_id: folder.id }, headers: auth_headers(owner)

      titles = response.parsed_body["documents"].map { |d| d["title"] }
      expect(titles).to eq([ "Assurance RC" ])
    end

    it "filters by expiring_soon" do
      create(:library_document, folder: folder, title: "Expiring", expires_on: 10.days.from_now.to_date)
      create(:library_document, folder: folder, title: "Not expiring", expires_on: 200.days.from_now.to_date)
      create(:library_document, folder: folder, title: "No expiry")

      get "/api/v1/library_documents", params: { status: "expiring_soon" }, headers: auth_headers(owner)

      titles = response.parsed_body["documents"].map { |d| d["title"] }
      expect(titles).to eq([ "Expiring" ])
    end

    it "never exposes another company's documents" do
      create(:library_document, folder: folder)
      other_org_document = create(:library_document)

      get "/api/v1/library_documents", headers: auth_headers(owner)

      ids = response.parsed_body["documents"].map { |d| d["id"] }
      expect(ids).not_to include(other_org_document.id)
    end
  end

  describe "PATCH /api/v1/library_documents/:id" do
    it "updates a document's title without re-uploading the file" do
      document = create(:library_document, folder: folder, title: "Old title")

      patch "/api/v1/library_documents/#{document.id}", params: { library_document: { title: "New title" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["document"]["title"]).to eq("New title")
      expect(response.parsed_body["document"]["file"]).to be_present
    end

    it "moves a document to a different folder in the same company" do
      document = create(:library_document, folder: folder)
      other_folder = create(:library_folder, company: company, name: "Juridique")

      patch "/api/v1/library_documents/#{document.id}", params: { library_document: { folder_id: other_folder.id } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["document"]["folder_id"]).to eq(other_folder.id)
    end
  end

  describe "GET /api/v1/library_documents/:id/file" do
    it "streams the attached file to an authorized user" do
      document = create(:library_document, folder: folder)

      get "/api/v1/library_documents/#{document.id}/file", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to eq("image/png")
    end

    it "forbids a coach from downloading a document" do
      document = create(:library_document, folder: folder)
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/library_documents/#{document.id}/file", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/library_documents/:id" do
    it "deletes a document" do
      document = create(:library_document, folder: folder)

      delete "/api/v1/library_documents/#{document.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:no_content)
      expect(LibraryDocument.exists?(document.id)).to be false
    end
  end
end
