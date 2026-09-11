require "rails_helper"

RSpec.describe Bookings::Cancel do
  it "cancels a confirmed booking" do
    booking = create(:booking, status: :confirmed)

    result = described_class.call(booking: booking)

    expect(result.success?).to be true
    expect(result.error).to be_nil
    expect(booking.reload).to be_cancelled
  end

  it "restores availability on a limited contract when cancelling" do
    contract_type = create(:contract_type, unlimited_bookings: false)
    contract = create(:contract, contract_type: contract_type, remaining_bookings: 3)
    booking = create(:booking, client: contract.client, status: :confirmed, contract_period: contract.current_period)

    result = described_class.call(booking: booking)

    expect(result.success?).to be true
    expect(contract.current_period.reload.remaining_bookings).to eq(4)
  end

  it "does not touch remaining_bookings for an unlimited contract" do
    contract_type = create(:contract_type, unlimited_bookings: true)
    contract = create(:contract, contract_type: contract_type)
    booking = create(:booking, client: contract.client, status: :confirmed, contract_period: contract.current_period)

    result = described_class.call(booking: booking)

    expect(result.success?).to be true
    expect(contract.current_period.reload.remaining_bookings).to be_nil
  end

  it "cancels a booking with no linked contract period" do
    booking = create(:booking, status: :confirmed, contract_period: nil)

    result = described_class.call(booking: booking)

    expect(result.success?).to be true
    expect(booking.reload).to be_cancelled
  end

  it "rejects cancelling an already cancelled booking" do
    booking = create(:booking, status: :cancelled)

    result = described_class.call(booking: booking)

    expect(result.success?).to be false
    expect(result.error).to eq("This booking is already cancelled.")
    expect(booking.reload).to be_cancelled
  end
end
