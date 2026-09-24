require "rails_helper"

RSpec.describe PasswordResettable, type: :model do
  # Tested through User — the only model that signs in.
  let(:user) { create(:user, :admin) }

  it "generates a token whose digest is persisted, never the raw value" do
    raw = user.generate_password_reset_token!

    expect(user.reset_password_token_digest).to be_present
    expect(user.reset_password_token_digest).not_to eq(raw)
  end

  it "validates the raw token against the stored digest" do
    raw = user.generate_password_reset_token!

    expect(user.password_reset_token_valid?(raw)).to be true
    expect(user.password_reset_token_valid?("wrong-token")).to be false
  end

  it "expires after the token window" do
    raw = user.generate_password_reset_token!
    user.update!(reset_password_sent_at: PasswordResettable::TOKEN_EXPIRY.ago - 1.minute)

    expect(user.password_reset_token_valid?(raw)).to be false
  end

  it "finds the record by raw token via the class method" do
    raw = user.generate_password_reset_token!

    expect(User.find_by_reset_password_token(raw)).to eq(user)
    expect(User.find_by_reset_password_token("nope")).to be_nil
  end

  it "clears the token after use" do
    raw = user.generate_password_reset_token!
    user.clear_password_reset_token!

    expect(user.reset_password_token_digest).to be_nil
    expect(User.find_by_reset_password_token(raw)).to be_nil
  end
end
