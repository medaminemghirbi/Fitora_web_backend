require "rails_helper"

RSpec.describe "Api::V1::Spaces", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner, settings: { features: { spaces: true } }) }

  describe "the feature flag" do
    it "404s for a gym that has not turned rooms on" do
      company.update!(settings: { features: { spaces: false } })

      get "/api/v1/spaces", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "serves the list once rooms are on" do
      create(:space, company: company)

      get "/api/v1/spaces", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["spaces"].size).to eq(1)
    end
  end

  describe "GET /api/v1/spaces" do
    it "never exposes another gym's rooms" do
      mine = create(:space, company: company)
      theirs = create(:space)

      get "/api/v1/spaces", headers: auth_headers(owner)

      ids = response.parsed_body["spaces"].map { |s| s["id"] }
      expect(ids).to include(mine.id)
      expect(ids).not_to include(theirs.id)
    end

    it "lets a receptionist read them — needed to fill the new-session form" do
      create(:space, company: company)
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/spaces", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a coach, who has neither the rooms nor the schedule capability" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/spaces", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "searches by name" do
      create(:space, company: company, name: "Reformer Studio")
      create(:space, company: company, name: "Boxing Ring")

      get "/api/v1/spaces", params: { q: "reformer" }, headers: auth_headers(owner)

      expect(response.parsed_body["spaces"].map { |s| s["name"] }).to eq([ "Reformer Studio" ])
    end
  end

  describe "GET /api/v1/spaces/:id" do
    it "404s for another gym's room rather than saying it exists" do
      theirs = create(:space)

      get "/api/v1/spaces/#{theirs.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/spaces" do
    it "creates a room for the owner's own gym" do
      post "/api/v1/spaces",
           params: { space: { name: "Studio 2", kind: "studio", capacity: 10 } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(company.spaces.pluck(:name)).to include("Studio 2")
    end

    it "ignores a company_id in the body and uses the caller's own gym" do
      other = create(:company)

      post "/api/v1/spaces",
           params: { space: { name: "Smuggled", company_id: other.id } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(Space.find_by(name: "Smuggled").company_id).to eq(company.id)
      expect(other.spaces).to be_empty
    end

    it "forbids a receptionist — the room catalogue is not a desk job" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/spaces", params: { space: { name: "Nope" } }, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "reports a duplicate name rather than raising" do
      create(:space, company: company, name: "Studio A")

      post "/api/v1/spaces", params: { space: { name: "Studio A" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to be_present
    end

    it "links only the gym's own activities when restricting a room" do
      mine = create(:activity, company: company)
      theirs = create(:activity)

      post "/api/v1/spaces",
           params: { space: { name: "Studio 3", activity_ids: [ mine.id, theirs.id ] } },
           headers: auth_headers(owner)

      expect(response.parsed_body["space"]["activity_ids"]).to contain_exactly(mine.id)
    end
  end

  describe "PATCH /api/v1/spaces/:id" do
    it "updates the owner's own room" do
      space = create(:space, company: company, name: "Old")

      patch "/api/v1/spaces/#{space.id}", params: { space: { name: "New" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(space.reload.name).to eq("New")
    end

    it "404s for another gym's room" do
      theirs = create(:space)

      patch "/api/v1/spaces/#{theirs.id}", params: { space: { name: "Hijacked" } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.name).not_to eq("Hijacked")
    end
  end

  describe "DELETE /api/v1/spaces/:id" do
    it "deletes a room nothing is scheduled in" do
      space = create(:space, company: company)

      delete "/api/v1/spaces/#{space.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(Space.exists?(space.id)).to be(false)
    end

    it "only deactivates a room that still has sessions, keeping their history" do
      space = create(:space, company: company)
      session = create(:session, company: company, activity: create(:activity, company: company), space: space)

      delete "/api/v1/spaces/#{space.id}", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(space.reload.active).to be(false)
      expect(session.reload.space_id).to eq(space.id)
    end
  end

  it "rejects an unauthenticated caller" do
    get "/api/v1/spaces"

    expect(response).to have_http_status(:unauthorized)
  end
end
