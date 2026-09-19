require "rails_helper"

RSpec.describe CompanySettings do
  describe "defaults" do
    it "gives a company that has configured nothing a working set of rules" do
      settings = described_class.default

      expect(settings.feature?(:bookings)).to be(true)
      expect(settings.feature?(:spaces)).to be(false)
      expect(settings.feature?(:waitlist)).to be(false)
      expect(settings.cancellation_hours).to eq(2)
      expect(settings.booking_opens_days).to eq(14)
    end

    it "treats a nil or junk column as empty rather than blowing up" do
      expect(described_class.new(nil).feature?(:bookings)).to be(true)
      expect(described_class.new("nonsense").cancellation_hours).to eq(2)
    end

    it "is false for a feature that does not exist" do
      expect(described_class.default.feature?(:teleportation)).to be(false)
    end
  end

  describe "the closed surface" do
    it "drops keys it does not declare instead of storing them" do
      settings = described_class.new(
        features: { spaces: true, crypto_payments: true },
        booking: { cancellation_hours: 6, moon_phase: "waxing" },
        billing: { anything: 1 }
      )

      expect(settings.to_h[:features]).not_to have_key(:crypto_payments)
      expect(settings.to_h[:booking]).not_to have_key(:moon_phase)
      expect(settings.to_h).not_to have_key(:billing)
      expect(settings.unknown_keys).to contain_exactly("features.crypto_payments", "booking.moon_phase", "billing")
    end

    it "still keeps the declared keys that came alongside the junk" do
      settings = described_class.new(features: { spaces: true, nonsense: true })

      expect(settings.feature?(:spaces)).to be(true)
    end
  end

  describe "casting" do
    it "accepts the booleans a JSON body or a form actually sends" do
      expect(described_class.new(features: { spaces: "true" }).feature?(:spaces)).to be(true)
      expect(described_class.new(features: { spaces: 1 }).feature?(:spaces)).to be(true)
      expect(described_class.new(features: { bookings: "false" }).feature?(:bookings)).to be(false)
      expect(described_class.new(features: { bookings: 0 }).feature?(:bookings)).to be(false)
    end

    it "falls back to the default rather than reading a typo as false" do
      expect(described_class.new(features: { bookings: "yes please" }).feature?(:bookings)).to be(true)
    end

    it "parses a numeric string" do
      expect(described_class.new(booking: { cancellation_hours: "12" }).cancellation_hours).to eq(12)
    end

    it "clamps an out-of-range number to the nearest legal value" do
      expect(described_class.new(booking: { cancellation_hours: 10_000 }).cancellation_hours).to eq(168)
      expect(described_class.new(booking: { cancellation_hours: -5 }).cancellation_hours).to eq(0)
    end

    it "keeps zero, which means 'right up to the start'" do
      expect(described_class.new(booking: { cancellation_hours: 0 }).cancellation_hours).to eq(0)
    end
  end

  describe "#merge" do
    it "changes only what the patch names" do
      settings = described_class.new(features: { spaces: true }, booking: { cancellation_hours: 24 })

      merged = settings.merge(booking: { booking_opens_days: 30 })

      expect(merged.booking_opens_days).to eq(30)
      expect(merged.cancellation_hours).to eq(24)
      expect(merged.feature?(:spaces)).to be(true)
    end

    it "returns a new object and leaves the original alone" do
      settings = described_class.new(features: { spaces: true })

      merged = settings.merge(features: { spaces: false })

      expect(merged.feature?(:spaces)).to be(false)
      expect(settings.feature?(:spaces)).to be(true)
    end

    it "is a no-op for a patch that is not a hash" do
      settings = described_class.new(features: { spaces: true })

      expect(settings.merge(nil)).to eq(settings)
    end
  end

  describe "round-tripping through the column" do
    it "survives being written and read back" do
      company = create(:company)
      company.settings = { features: { spaces: true, waitlist: true }, booking: { cancellation_hours: 48 } }
      company.save!

      reloaded = Company.find(company.id)

      expect(reloaded.feature?(:spaces)).to be(true)
      expect(reloaded.feature?(:waitlist)).to be(true)
      expect(reloaded.settings.cancellation_hours).to eq(48)
    end

    it "keeps earlier settings when a later write touches one section" do
      company = create(:company)
      company.update!(settings: { features: { spaces: true } })
      company.update!(settings: { booking: { cancellation_hours: 5 } })

      expect(company.reload.feature?(:spaces)).to be(true)
      expect(company.settings.cancellation_hours).to eq(5)
    end

    it "clears the memoized object on reload" do
      company = create(:company)
      company.settings
      Company.find(company.id).update!(settings: { features: { spaces: true } })

      expect(company.reload.feature?(:spaces)).to be(true)
    end
  end
end
