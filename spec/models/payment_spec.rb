require "rails_helper"

RSpec.describe Payment do
  let(:company) { create(:company) }
  let(:client) { create(:client, company: company) }
  let(:booking) { create(:booking, client: client) }

  it "rejects a new card payment (card is out of scope for now)" do
    payment = build(:payment, client: client, company: company, booking: booking, payment_method: :card)
    expect(payment).not_to be_valid
    expect(payment.errors[:payment_method]).to be_present
  end

  it "accepts the selectable methods" do
    Payment::SELECTABLE_METHODS.each do |method|
      payment = build(:payment, client: client, company: company, booking: booking, payment_method: method)
      expect(payment).to be_valid, "expected #{method} to be valid"
    end
  end

  it "still lets a legacy card payment be re-saved without changing the method" do
    legacy = build(:payment, client: client, company: company, booking: booking, payment_method: :card)
    legacy.save!(validate: false)

    legacy.update!(notes: "reconciled")
    expect(legacy.reload.payment_method).to eq("card")
  end
end
