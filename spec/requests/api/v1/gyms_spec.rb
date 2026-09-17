require "rails_helper"

RSpec.describe "Api::V1::Gyms", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:listed) { create(:company, owner: owner, name: "Power Gym", city: "Tunis", listed_at: Time.current) }
  let!(:unlisted) { create(:company, :unlisted, name: "Salle privée", city: "Tunis") }

  describe "GET /api/v1/gyms" do
    it "is open to anyone, with no login at all" do
      get "/api/v1/gyms"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["gyms"].map { |g| g["name"] }).to eq([ "Power Gym" ])
    end

    it "never lists a gym whose owner stepped out of the directory" do
      get "/api/v1/gyms"

      expect(response.parsed_body["gyms"].map { |g| g["id"] }).not_to include(unlisted.id)
    end

    it "leaves out a gym that has been deactivated" do
      listed.update!(active: false)

      get "/api/v1/gyms"

      expect(response.parsed_body["gyms"]).to be_empty
    end

    it "searches on the gym's name, its city and the activities it offers" do
      create(:activity, company: listed, name: "Aquagym")

      get "/api/v1/gyms", params: { q: "aquagym" }
      expect(response.parsed_body["gyms"].map { |g| g["id"] }).to eq([ listed.id ])

      get "/api/v1/gyms", params: { q: "tunis" }
      expect(response.parsed_body["gyms"].map { |g| g["id"] }).to eq([ listed.id ])

      get "/api/v1/gyms", params: { q: "introuvable" }
      expect(response.parsed_body["gyms"]).to be_empty
    end

    it "shows only what a gym publishes about itself, never its members or its money" do
      create(:client, company: listed)

      get "/api/v1/gyms"

      gym = response.parsed_body["gyms"].first
      expect(gym.keys).to contain_exactly(
        "id", "slug", "name", "city", "country", "description",
        "logo_url", "primary_color", "currency", "distance_km", "activity_names"
      )
    end
  end

  describe "GET /api/v1/gyms/:id" do
    it "returns the gym's page with the activities it offers" do
      create(:activity, company: listed, name: "Boxe")

      get "/api/v1/gyms/#{listed.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["gym"]["activities"].map { |a| a["name"] }).to eq([ "Boxe" ])
    end

    it "404s for a gym that stepped out, rather than hinting it exists" do
      get "/api/v1/gyms/#{unlisted.id}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the nearest gyms first" do
    # Tunis, then Sfax — roughly 235 km apart.
    let!(:near) { create(:company, name: "Tunis Gym", listed_at: Time.current, latitude: 36.8065, longitude: 10.1815) }
    let!(:far) { create(:company, name: "Sfax Gym", listed_at: Time.current, latitude: 34.7406, longitude: 10.7603) }

    it "orders by distance from the browser's position and says how far each one is" do
      get "/api/v1/gyms", params: { lat: 36.81, lng: 10.18 }

      gyms = response.parsed_body["gyms"]
      names = gyms.map { |g| g["name"] }
      expect(names.index("Tunis Gym")).to be < names.index("Sfax Gym")

      by_name = gyms.to_h { |g| [ g["name"], g["distance_km"] ] }
      expect(by_name["Tunis Gym"]).to be < 5
      expect(by_name["Sfax Gym"]).to be_within(20).of(235)
    end

    it "still lists a gym whose owner never set its coordinates, after the located ones" do
      get "/api/v1/gyms", params: { lat: 36.81, lng: 10.18 }

      gyms = response.parsed_body["gyms"]
      unlocated = gyms.find { |g| g["name"] == "Power Gym" }
      expect(unlocated).to be_present
      expect(unlocated["distance_km"]).to be_nil
      expect(gyms.index(unlocated)).to be > gyms.index(gyms.find { |g| g["name"] == "Tunis Gym" })
    end

    it "falls back to alphabetical order when the position is missing or nonsense" do
      get "/api/v1/gyms", params: { lat: "ici", lng: "la-bas" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["gyms"].map { |g| g["name"] }).to eq([ "Power Gym", "Sfax Gym", "Tunis Gym" ])

      get "/api/v1/gyms", params: { lat: 999, lng: 10 }
      expect(response.parsed_body["gyms"].map { |g| g["name"] }).to eq([ "Power Gym", "Sfax Gym", "Tunis Gym" ])
    end

    it "keeps the search narrowing the list, position or not" do
      create(:activity, company: far, name: "Aquagym")

      get "/api/v1/gyms", params: { q: "aquagym", lat: 36.81, lng: 10.18 }

      expect(response.parsed_body["gyms"].map { |g| g["name"] }).to eq([ "Sfax Gym" ])
    end
  end

  describe "the week ahead on a gym's page" do
    let(:activity) { create(:activity, company: listed, name: "Pilates") }
    let(:coach) do
      create(:coach, company: listed, first_name: "Sonia", last_name: "Mabrouk").tap do |c|
      end
    end

    def public_session(starts_at:, capacity: 12, status: :scheduled)
      create(:session, activity: activity, company: listed, coach: coach, capacity: capacity,
                       status: status, starts_at: starts_at, ends_at: starts_at + 1.hour)
    end

    it "shows the coming sessions to someone with no account and no membership" do
      public_session(starts_at: 2.days.from_now.change(hour: 18))

      get "/api/v1/gyms/#{listed.id}"

      session = response.parsed_body["gym"]["sessions"].first
      expect(session["activity_name"]).to eq("Pilates")
      expect(session["coach_name"]).to eq("Sonia Mabrouk")
      expect(session["spots_left"]).to eq(12)
      expect(session["full"]).to be false
    end

    it "shows how much room is left, never who is in the room nor how many" do
      session = public_session(starts_at: 2.days.from_now.change(hour: 18), capacity: 2)
      create(:booking, session: session, client: create(:client, company: listed), status: :confirmed)

      get "/api/v1/gyms/#{listed.id}"

      payload = response.parsed_body["gym"]["sessions"].first
      expect(payload["spots_left"]).to eq(1)
      expect(payload.keys).to contain_exactly(
        "id", "activity_name", "activity_emoji", "coach_name",
        "starts_at", "ends_at", "capacity", "spots_left", "full"
      )
    end

    it "never publishes what a session or a plan costs" do
      public_session(starts_at: 1.day.from_now.change(hour: 9))

      get "/api/v1/gyms/#{listed.id}"

      body = response.body
      expect(body).not_to include("price")
      expect(response.parsed_body["gym"]).not_to have_key("contract_types")
    end

    it "stops at seven days, and leaves out what has passed or been cancelled" do
      soon = public_session(starts_at: 1.day.from_now.change(hour: 9))
      public_session(starts_at: 20.days.from_now.change(hour: 9))
      public_session(starts_at: 2.days.from_now.change(hour: 9), status: :cancelled)

      get "/api/v1/gyms/#{listed.id}"

      expect(response.parsed_body["gym"]["sessions"].map { |s| s["id"] }).to eq([ soon.id ])
    end

    it "never shows another gym's schedule" do
      other = create(:company, listed_at: Time.current)
      other_activity = create(:activity, company: other)
      create(:session, activity: other_activity, company: other,
             starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour, status: :scheduled)

      get "/api/v1/gyms/#{listed.id}"

      expect(response.parsed_body["gym"]["sessions"]).to be_empty
    end

    it "keeps the schedule off the directory listing, which stays a summary" do
      public_session(starts_at: 1.day.from_now.change(hour: 9))

      get "/api/v1/gyms"

      expect(response.parsed_body["gyms"].first).not_to have_key("sessions")
    end
  end

  describe "a gym is in the directory from the day it opens" do
    it "lists a brand new gym without anyone publishing it" do
      fresh = create(:company, name: "Nouvelle Salle")

      get "/api/v1/gyms"

      expect(response.parsed_body["gyms"].map { |g| g["id"] }).to include(fresh.id)
      expect(fresh.reload).to be_listed
    end

    it "keeps a gym out once its owner steps out, and lets it come back" do
      fresh = create(:company, name: "Nouvelle Salle")

      fresh.unpublish!
      get "/api/v1/gyms"
      expect(response.parsed_body["gyms"].map { |g| g["id"] }).not_to include(fresh.id)

      fresh.publish!
      get "/api/v1/gyms"
      expect(response.parsed_body["gyms"].map { |g| g["id"] }).to include(fresh.id)
    end
  end
end
