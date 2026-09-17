require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    it "no longer exists — a gym asks for a demo or a quote instead of signing itself up" do
      post "/api/v1/auth/register", params: {
        first_name: "Amine", last_name: "M", email: "new@example.com", password: "password123"
      }

      expect(response).to have_http_status(:not_found)
      expect(User.find_by(email: "new@example.com")).to be_nil
    end
  end

  describe "POST /api/v1/auth/login" do
    it "returns a token for valid credentials" do
      create(:user, email: "login@example.com", password: "password123")

      post "/api/v1/auth/login", params: { email: "login@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["token"]).to be_present
    end

    it "rejects invalid credentials" do
      create(:user, email: "login2@example.com", password: "password123")

      post "/api/v1/auth/login", params: { email: "login2@example.com", password: "wrong" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "falls back to a client's own login when no user matches" do
      client = create(:client, email: "client-login@example.com", password: "password123")

      post "/api/v1/auth/login", params: { email: "client-login@example.com", password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["account_type"]).to eq("client")
      expect(response.parsed_body["client"]["id"]).to eq(client.id)
      expect(response.parsed_body["token"]).to be_present
    end

    it "rejects a client with no login configured, even with a correct-looking email" do
      create(:client, email: "no-login@example.com")

      post "/api/v1/auth/login", params: { email: "no-login@example.com", password: "whatever123" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a client's wrong password" do
      create(:client, email: "client-login2@example.com", password: "password123")

      post "/api/v1/auth/login", params: { email: "client-login2@example.com", password: "wrong" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/auth/me" do
    it "requires authentication" do
      get "/api/v1/auth/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the current user when authenticated" do
      user = create(:user)

      get "/api/v1/auth/me", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]["id"]).to eq(user.id)
    end

    it "returns the current client when authenticated with a client token" do
      client = create(:client, email: "me-client@example.com", password: "password123")

      get "/api/v1/auth/me", headers: auth_headers(client)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["account_type"]).to eq("client")
      expect(response.parsed_body["client"]["id"]).to eq(client.id)
    end
  end
end
