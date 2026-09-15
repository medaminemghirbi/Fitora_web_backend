require "rails_helper"

RSpec.describe "Api::V1::Salles", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/salles" do
    it "never exposes another company's salles" do
      mine = create(:salle, location: company.location)
      theirs = create(:salle)

      get "/api/v1/salles", headers: auth_headers(owner)

      ids = response.parsed_body["salles"].map { |s| s["id"] }
      expect(ids).to include(mine.id)
      expect(ids).not_to include(theirs.id)
    end

    it "lets any active staff member browse the salles — facility info, not a privileged view" do
      create(:salle, location: company.location)
      coach = create(:staff_member, company: company, role: :coach)

      get "/api/v1/salles", headers: auth_headers(coach.user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["salles"].size).to eq(1)
    end

    it "forbids an unauthenticated request" do
      get "/api/v1/salles"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/salles/:id" do
    it "404s for another company's salle" do
      other = create(:salle)

      get "/api/v1/salles/#{other.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/salles" do
    it "creates a salle attached to the company's one location" do
      post "/api/v1/salles", params: { salle: { name: "Salle de musculation", capacity: 30, description: "Free weights and machines" } },
                              headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["salle"]
      expect(body["name"]).to eq("Salle de musculation")
      expect(body["location_id"]).to eq(company.location.id)
      expect(body["image_urls"]).to eq([])
    end

    it "rejects a salle with no capacity" do
      post "/api/v1/salles", params: { salle: { name: "Studio" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "accepts multiple image uploads" do
      images = [
        fixture_file_upload("sample.png", "image/png"),
        fixture_file_upload("sample.png", "image/png")
      ]

      post "/api/v1/salles", params: { salle: { name: "Studio Yoga", capacity: 15, images: images } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["salle"]["image_urls"].size).to eq(2)
    end

    it "rejects a non-image upload, keyed on the images field" do
      bad_file = fixture_file_upload("sample.txt", "text/plain")

      post "/api/v1/salles", params: { salle: { name: "Studio", capacity: 10, images: [ bad_file ] } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include(a_string_matching(/images/i))
    end

    it "forbids a receptionist — managing salles needs the locations capability" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/salles", params: { salle: { name: "Studio", capacity: 10 } }, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/salles/:id" do
    it "updates a salle's attributes" do
      salle = create(:salle, location: company.location, name: "Old name")

      patch "/api/v1/salles/#{salle.id}", params: { salle: { name: "New name", capacity: 25 } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(salle.reload.name).to eq("New name")
      expect(salle.capacity).to eq(25)
    end

    it "leaves the existing gallery untouched when :images is omitted" do
      salle = create(:salle, location: company.location)
      salle.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.png")), filename: "room.png", content_type: "image/png")

      patch "/api/v1/salles/#{salle.id}", params: { salle: { name: "Renamed" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(salle.reload.images.count).to eq(1)
    end

    it "replaces the gallery when :images is sent" do
      salle = create(:salle, location: company.location)
      salle.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.png")), filename: "room.png", content_type: "image/png")

      patch "/api/v1/salles/#{salle.id}", params: { salle: { images: [ fixture_file_upload("sample.png", "image/png") ] } },
                                           headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(salle.reload.images.count).to eq(1)
    end
  end

  describe "DELETE /api/v1/salles/:id" do
    it "soft-deactivates rather than destroying the row" do
      salle = create(:salle, location: company.location)

      delete "/api/v1/salles/#{salle.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(salle.reload.active).to be(false)
      expect(Salle.exists?(salle.id)).to be(true)
    end

    it "forbids a coach from deleting a salle" do
      salle = create(:salle, location: company.location)
      coach = create(:staff_member, company: company, role: :coach)

      delete "/api/v1/salles/#{salle.id}", headers: auth_headers(coach.user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
