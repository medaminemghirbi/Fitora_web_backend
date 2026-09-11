require "rails_helper"

# Guards against db/seeds.rb rotting as models change. Runs the whole seed
# file inside the example's transaction (use_transactional_fixtures), so it
# leaves nothing behind. Kept deliberately light — it asserts the seed
# produces a coherent starting point, not every individual row.
RSpec.describe "db/seeds.rb" do
  it "runs cleanly and is idempotent" do
    expect {
      silence_stream($stdout) { Rails.application.load_seed }
      silence_stream($stdout) { Rails.application.load_seed }
    }.not_to raise_error

    expect(User.find_by(email: "admin@fitora.test")&.role).to eq("admin")
    # Minimal bootstrap only — no demo gym/owner/staff/clients.
    expect(User.where(role: :owner).count).to eq(0)
    expect(Company.count).to eq(0)
    expect(SubscriptionPrice.find_by(currency: "TND")&.monthly_cents).to eq(SubscriptionPrice::DEFAULT_MONTHLY_CENTS)
    expect(PlatformSetting.count).to eq(1)
  end

  private

  def silence_stream(stream)
    old = stream.dup
    stream.reopen(File::NULL)
    stream.sync = true
    yield
  ensure
    stream.reopen(old)
    old.close
  end
end
