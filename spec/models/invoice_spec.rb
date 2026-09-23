require "rails_helper"

RSpec.describe Invoice do
  describe ".next_number" do
    it "starts a year at one and counts up" do
      travel_to(Date.new(2026, 3, 1)) do
        expect(described_class.next_number).to eq("FIT-2026-0001")
        create(:invoice, number: described_class.next_number)
        expect(described_class.next_number).to eq("FIT-2026-0002")
      end
    end

    it "restarts the count in a new year" do
      create(:invoice, number: "FIT-2026-0042")

      travel_to(Date.new(2027, 1, 4)) do
        expect(described_class.next_number).to eq("FIT-2027-0001")
      end
    end

    it "never hands out the same number twice" do
      first = create(:invoice, number: described_class.next_number)

      expect { create(:invoice, number: first.number) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  it "refuses a period that runs backwards" do
    invoice = build(:invoice, period_start: Date.current, period_end: Date.current - 1)

    expect(invoice).not_to be_valid
    expect(invoice.errors[:period_end]).to be_present
  end

  it "knows which day it covers" do
    invoice = build(:invoice, period_start: Date.new(2026, 9, 1), period_end: Date.new(2026, 9, 30))

    expect(invoice).to be_covers(Date.new(2026, 9, 15))
    expect(invoice).not_to be_covers(Date.new(2026, 10, 1))
  end
end
