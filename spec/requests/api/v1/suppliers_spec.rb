require "rails_helper"

RSpec.describe "Api::V1::Suppliers", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  context "suppliers" do
    describe "GET /api/v1/suppliers" do
      it "lists this company's suppliers, alphabetically" do
        create(:supplier, company: company, name: "Zenith Fournitures")
        create(:supplier, company: company, name: "Alpha Sport")
        create(:supplier)

        get "/api/v1/suppliers", headers: auth_headers(owner)

        names = response.parsed_body["suppliers"].map { |s| s["name"] }
        expect(names).to eq([ "Alpha Sport", "Zenith Fournitures" ])
      end

      it "filters by search across name/category/contact/phone/email" do
        create(:supplier, company: company, name: "Alpha Sport", category: "Textile")
        create(:supplier, company: company, name: "Beta Nutrition", category: "Alimentaire")

        get "/api/v1/suppliers", params: { search: "textile" }, headers: auth_headers(owner)

        names = response.parsed_body["suppliers"].map { |s| s["name"] }
        expect(names).to eq([ "Alpha Sport" ])
      end
    end

    describe "POST /api/v1/suppliers" do
      it "creates a supplier" do
        post "/api/v1/suppliers", params: { supplier: { name: "Alpha Sport", category: "Textile", phone: "20111222" } }, headers: auth_headers(owner)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["supplier"]["name"]).to eq("Alpha Sport")
      end

      it "rejects a supplier with no name" do
        post "/api/v1/suppliers", params: { supplier: { category: "Textile" } }, headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to eq({ "name" => [ "can't be blank" ] })
      end

      it "accepts a photo upload" do
        photo = fixture_file_upload("sample.png", "image/png")

        post "/api/v1/suppliers", params: { supplier: { name: "Alpha Sport", photo: photo } }, headers: auth_headers(owner)

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["supplier"]["photo_url"]).to be_present
      end

      it "rejects a non-image photo upload, keyed on the photo field" do
        # Active Storage sniffs the real bytes (Marcel) rather than trusting
        # the multipart content-type header, so this needs an actually
        # non-image file to trigger a real rejection.
        bad_file = fixture_file_upload("sample.txt", "text/plain")

        post "/api/v1/suppliers", params: { supplier: { name: "Alpha Sport", photo: bad_file } }, headers: auth_headers(owner)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]["photo"]).to be_present
      end
    end

    describe "PATCH /api/v1/suppliers/:id" do
      it "updates a supplier" do
        supplier = create(:supplier, company: company)

        patch "/api/v1/suppliers/#{supplier.id}", params: { supplier: { name: "Renamed" } }, headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        expect(supplier.reload.name).to eq("Renamed")
      end
    end

    describe "DELETE /api/v1/suppliers/:id" do
      it "soft-deactivates rather than destroying the row" do
        supplier = create(:supplier, company: company)

        delete "/api/v1/suppliers/#{supplier.id}", headers: auth_headers(owner)

        expect(response).to have_http_status(:ok)
        expect(supplier.reload.active).to be(false)
      end
    end
  end
end
