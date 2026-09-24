require "rails_helper"

RSpec.describe "Api::V1::PasswordResets", type: :request do
  describe "POST /api/v1/password_resets" do
    it "sends a reset email for a matching admin and always returns 204" do
      admin = create(:user, :admin, email: "owner@example.test")

      expect {
        post "/api/v1/password_resets", params: { email: "owner@example.test" }
      }.to have_enqueued_mail(AccountMailer, :password_reset)

      expect(response).to have_http_status(:no_content)
      expect(admin.reload.reset_password_token_digest).to be_present
    end

    it "never sends anything for a platform superadmin, but still returns 204" do
      create(:user, :superadmin, email: "admin@example.test")

      expect {
        post "/api/v1/password_resets", params: { email: "admin@example.test" }
      }.not_to have_enqueued_mail(AccountMailer, :password_reset)

      expect(response).to have_http_status(:no_content)
    end

    it "returns 204 for an unknown email too — no enumeration" do
      expect {
        post "/api/v1/password_resets", params: { email: "nobody@example.test" }
      }.not_to have_enqueued_mail

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PATCH /api/v1/password_resets/:token" do
    it "resets the password with a valid token" do
      user = create(:user, :admin)
      raw = user.generate_password_reset_token!

      patch "/api/v1/password_resets/#{raw}", params: { password: "new-strong-password" }

      expect(response).to have_http_status(:no_content)
      expect(user.reload.authenticate("new-strong-password")).to eq(user)
      expect(user.reset_password_token_digest).to be_nil
    end

    it "rejects an invalid token" do
      patch "/api/v1/password_resets/not-a-real-token", params: { password: "new-strong-password" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a token belonging to a platform superadmin" do
      superadmin = create(:user, :superadmin)
      raw = superadmin.generate_password_reset_token!

      patch "/api/v1/password_resets/#{raw}", params: { password: "new-strong-password" }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects an expired token" do
      user = create(:user, :admin)
      raw = user.generate_password_reset_token!
      user.update!(reset_password_sent_at: PasswordResettable::TOKEN_EXPIRY.ago - 1.minute)

      patch "/api/v1/password_resets/#{raw}", params: { password: "new-strong-password" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
