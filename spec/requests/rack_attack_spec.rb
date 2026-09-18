require "rails_helper"

# Disabled in test by default (config/initializers/rack_attack.rb) so it
# never makes unrelated specs flaky — enabled here, for these examples
# only, to prove the real throttle behaves as configured.
RSpec.describe "Rack::Attack throttling on login", type: :request do
  around do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.reset!
    example.run
  ensure
    Rack::Attack.cache.reset!
    Rack::Attack.enabled = false
  end

  describe "POST /api/v1/auth/login" do
    it "throttles a single IP after too many attempts, regardless of the email tried" do
      60.times { |i| post "/api/v1/auth/login", params: { email: "nobody#{i}@example.test", password: "wrong" } }
      expect(response).to have_http_status(:unauthorized) # still under the limit — ordinary failed logins

      post "/api/v1/auth/login", params: { email: "nobody99@example.test", password: "wrong" }

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body["error"]).to eq("rate_limited")
    end

    it "throttles repeated attempts against one email even from different IPs" do
      5.times { |i| post "/api/v1/auth/login", params: { email: "target@example.test", password: "wrong" }, headers: { "REMOTE_ADDR" => "10.0.0.#{i}" } }

      post "/api/v1/auth/login", params: { email: "target@example.test", password: "wrong" }, headers: { "REMOTE_ADDR" => "10.0.0.99" }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "does not throttle a normal, low-volume login" do
      user = create(:user, :owner, password: "password123")

      post "/api/v1/auth/login", params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/password_resets" do
    it "throttles repeated reset requests from one IP" do
      5.times { post "/api/v1/password_resets", params: { email: "someone@example.test" } }

      post "/api/v1/password_resets", params: { email: "someone@example.test" }

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  it "never throttles the internal /api namespace at large" do
    150.times { get "/api/v1/auth/me" }

    expect(response).not_to have_http_status(:too_many_requests)
  end
end
