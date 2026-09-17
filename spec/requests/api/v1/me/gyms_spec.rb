require "rails_helper"

RSpec.describe "Api::V1::Me::Gyms", type: :request do
  let(:gym) { create(:company, name: "Power Gym", listed_at: Time.current) }
  let(:other_gym) { create(:company, name: "Cross Lab", listed_at: Time.current) }
  let(:client) { create(:client, company: gym, password: "password123") }

  describe "GET /api/v1/me/gyms" do
    it "lists every gym the person belongs to" do
      client.join!(other_gym)

      get "/api/v1/me/gyms", headers: auth_headers(client)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["gyms"].map { |g| g["name"] }).to contain_exactly("Power Gym", "Cross Lab")
    end

    it "carries each gym's own subscription, never another gym's" do
      activity = create(:activity, company: gym)
      plan = create(:contract_type, company: gym, activity: activity)
      create(:contract, client: client, company: gym, contract_type: plan, activity: activity)
      client.join!(other_gym)

      get "/api/v1/me/gyms", headers: auth_headers(client)

      by_name = response.parsed_body["gyms"].to_h { |g| [ g["name"], g["current_contract"] ] }
      expect(by_name["Power Gym"]).to be_present
      expect(by_name["Cross Lab"]).to be_nil
    end
  end

  describe "POST /api/v1/me/gyms" do
    it "joins a published gym straight away, with nothing to approve" do
      post "/api/v1/me/gyms", params: { gym_id: other_gym.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:created)
      expect(client.reload.companies).to include(other_gym)
    end

    it "is idempotent — joining twice does not duplicate the membership" do
      post "/api/v1/me/gyms", params: { gym_id: gym.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:created)
      expect(client.memberships.where(company: gym).count).to eq(1)
    end

    it "refuses a gym that is not in the directory" do
      hidden = create(:company, :unlisted)

      post "/api/v1/me/gyms", params: { gym_id: hidden.id }, headers: auth_headers(client)

      expect(response).to have_http_status(:not_found)
      expect(client.reload.companies).not_to include(hidden)
    end

    it "is closed to a staff login" do
      post "/api/v1/me/gyms", params: { gym_id: gym.id }, headers: auth_headers(create(:user, :owner))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/me/gyms/:id" do
    it "leaves the gym, while the gym keeps its own books" do
      activity = create(:activity, company: gym)
      plan = create(:contract_type, company: gym, activity: activity)
      contract = create(:contract, client: client, company: gym, contract_type: plan, activity: activity)

      delete "/api/v1/me/gyms/#{gym.id}", headers: auth_headers(client)

      expect(response).to have_http_status(:no_content)
      expect(client.reload.companies).not_to include(gym)
      expect(Contract.find_by(id: contract.id)).to be_present
    end
  end
end
