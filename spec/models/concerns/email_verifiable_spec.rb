require "rails_helper"

RSpec.describe EmailVerifiable, type: :model do
  let(:user) { create(:user, :owner, :unverified) }

  it "starts unverified" do
    expect(user.email_verified?).to be false
  end

  it "generates a token whose digest is persisted, never the raw value" do
    raw = user.generate_email_verification_token!

    expect(user.email_verification_token_digest).to be_present
    expect(user.email_verification_token_digest).not_to eq(raw)
  end

  it "verifies and clears the token in one step" do
    raw = user.generate_email_verification_token!
    found = User.find_by_email_verification_token(raw)
    found.verify_email!

    expect(user.reload.email_verified?).to be true
    expect(user.email_verification_token_digest).to be_nil
  end

  it "expires after the token window" do
    raw = user.generate_email_verification_token!
    user.update!(email_verification_sent_at: EmailVerifiable::TOKEN_EXPIRY.ago - 1.minute)

    expect(User.find_by_email_verification_token(raw)).to be_nil
  end
end
