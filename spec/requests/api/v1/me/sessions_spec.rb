require "rails_helper"

RSpec.describe "Api::V1::Me::Sessions", type: :request do
  let(:company) { create(:company) }
  let(:client) { create(:client, company: company) }
  let(:activity) { create(:activity, company: company) }

  describe "authorization" do
    it "forbids a staff login" do
      staff = create(:staff_member, company: company)

      get "/api/v1/me/sessions", headers: auth_headers(staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/me/sessions" do
    it "lists this company's upcoming scheduled sessions, not other companies'" do
      own = create(:session, activity: activity, starts_at: 2.days.from_now)
      create(:session, starts_at: 2.days.from_now) # another company

      get "/api/v1/me/sessions", headers: auth_headers(client)

      ids = response.parsed_body["sessions"].map { |s| s["id"] }
      expect(ids).to eq([ own.id ])
    end

    it "excludes past sessions" do
      create(:session, activity: activity, starts_at: 2.days.ago, ends_at: 2.days.ago + 1.hour)

      get "/api/v1/me/sessions", headers: auth_headers(client)

      expect(response.parsed_body["sessions"]).to be_empty
    end

    it "flags a session the client already booked" do
      session = create(:session, activity: activity, starts_at: 2.days.from_now)
      create(:booking, client: client, session: session, status: :confirmed)

      get "/api/v1/me/sessions", headers: auth_headers(client)

      expect(response.parsed_body["sessions"].first["already_booked"]).to be(true)
    end
  end

  describe "across several gyms" do
    it "lists sessions from every gym the person belongs to, each saying where it is" do
      other = create(:company, name: "Cross Lab")
      client.join!(other)
      other_session = create(:session, activity: create(:activity, company: other), company: other,
                             status: :scheduled, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

      get "/api/v1/me/sessions", headers: auth_headers(client)

      gyms = response.parsed_body["sessions"].map { |s| s["company_name"] }
      expect(gyms).to include("Cross Lab")
      expect(response.parsed_body["sessions"].map { |s| s["id"] }).to include(other_session.id)
    end

    it "narrows to one gym when asked" do
      other = create(:company, name: "Cross Lab")
      client.join!(other)
      create(:session, activity: create(:activity, company: other), company: other,
             status: :scheduled, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

      get "/api/v1/me/sessions", params: { company_id: other.id }, headers: auth_headers(client)

      expect(response.parsed_body["sessions"].map { |s| s["company_name"] }).to all(eq("Cross Lab"))
    end

    it "404s for a gym the person has not joined, rather than leaking its schedule" do
      stranger = create(:company)
      create(:session, activity: create(:activity, company: stranger), company: stranger,
             status: :scheduled, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour)

      get "/api/v1/me/sessions", params: { company_id: stranger.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:not_found)
    end
  end
end
