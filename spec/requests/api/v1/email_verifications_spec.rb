require "rails_helper"

RSpec.describe "Api::V1::EmailVerifications", type: :request do
  describe "POST /api/v1/email_verifications" do
    it "sends a verification email to the signed-in owner" do
      owner = create(:user, :owner)

      expect {
        post "/api/v1/email_verifications", headers: auth_headers(owner)
      }.to have_enqueued_mail(AccountMailer, :email_verification)

      expect(response).to have_http_status(:no_content)
    end

    it "sends a verification email to a signed-in client" do
      client = create(:client, password: "password123")

      expect {
        post "/api/v1/email_verifications", headers: auth_headers(client)
      }.to have_enqueued_mail(AccountMailer, :email_verification)

      expect(response).to have_http_status(:no_content)
    end

    it "refuses a platform admin" do
      admin = create(:user, :admin)

      post "/api/v1/email_verifications", headers: auth_headers(admin)

      expect(response).to have_http_status(:forbidden)
    end

    it "refuses to resend once already verified" do
      owner = create(:user, :owner)
      owner.generate_email_verification_token!
      owner.verify_email!

      post "/api/v1/email_verifications", headers: auth_headers(owner)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires authentication" do
      post "/api/v1/email_verifications"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/email_verifications/:token" do
    it "verifies with a valid token" do
      owner = create(:user, :owner)
      raw = owner.generate_email_verification_token!

      patch "/api/v1/email_verifications/#{raw}"

      expect(response).to have_http_status(:no_content)
      expect(owner.reload.email_verified?).to be true
    end

    it "verifies a client with a valid token" do
      client = create(:client)
      raw = client.generate_email_verification_token!

      patch "/api/v1/email_verifications/#{raw}"

      expect(response).to have_http_status(:no_content)
      expect(client.reload.email_verified?).to be true
    end

    it "rejects an invalid token" do
      patch "/api/v1/email_verifications/not-a-real-token"

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a token belonging to a platform admin" do
      admin = create(:user, :admin)
      raw = admin.generate_email_verification_token!

      patch "/api/v1/email_verifications/#{raw}"

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
