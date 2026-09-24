require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
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

    it "rejects a client with no login configured, even with a correct-looking email" do
      create(:client, email: "no-login@example.com")

      post "/api/v1/auth/login", params: { email: "no-login@example.com", password: "whatever123" }

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
  end

  describe "POST /api/v1/auth/register" do
    let(:payload) do
      { user: { first_name: "Amine", last_name: "Mghirbi", email: "new@gym.test", password: "password123" } }
    end

    it "opens an admin login and nothing else — the gym is named on the next screen" do
      expect { post "/api/v1/auth/register", params: payload }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["account_type"]).to eq("user")
      expect(response.parsed_body["token"]).to be_present

      user = User.find_by(email: "new@gym.test")
      expect(user.role).to eq("admin")
      expect(user.active_company).to be_nil
      expect(Company.count).to eq(0)
    end

    it "sends them a confirmation email" do
      expect { post "/api/v1/auth/register", params: payload }
        .to have_enqueued_mail(AccountMailer, :email_verification)
    end

    it "never lets the form choose its own role" do
      post "/api/v1/auth/register", params: { user: payload[:user].merge(role: "superadmin") }

      expect(User.find_by(email: "new@gym.test").role).to eq("admin")
    end

    it "refuses an address that already has an account" do
      create(:user, email: "new@gym.test")

      expect { post "/api/v1/auth/register", params: payload }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses a password too short to be one" do
      post "/api/v1/auth/register", params: { user: payload[:user].merge(password: "short") }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to be_present
    end
  end
end
