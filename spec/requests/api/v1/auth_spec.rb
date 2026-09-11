require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    it "creates an owner account and returns a token — this is how a gym signs up for Fitora" do
      post "/api/v1/auth/register", params: {
        first_name: "Jane", last_name: "Doe", email: "jane@example.com", password: "password123"
      }

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq("jane@example.com")
      expect(body["user"]["role"]).to eq("owner")
    end

    it "rejects a duplicate email" do
      create(:user, email: "dup@example.com")

      post "/api/v1/auth/register", params: {
        first_name: "Jane", last_name: "Doe", email: "dup@example.com", password: "password123"
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "never allows self-registering as admin or staff — always owner" do
      post "/api/v1/auth/register", params: {
        first_name: "Jane", last_name: "Doe", email: "jane2@example.com", password: "password123", role: "admin"
      }

      expect(response.parsed_body["user"]["role"]).to eq("owner")
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
