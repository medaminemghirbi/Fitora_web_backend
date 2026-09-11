require "rails_helper"

RSpec.describe Payments::Refund do
  it "refunds a paid payment" do
    payment = create(:payment, status: :paid)

    result = described_class.call(payment: payment)

    expect(result.success?).to be true
    expect(result.error).to be_nil
    expect(payment.reload).to be_refunded
  end

  it "rejects refunding a payment that is already refunded" do
    payment = create(:payment, status: :refunded)

    result = described_class.call(payment: payment)

    expect(result.success?).to be false
    expect(result.error).to eq("Only paid payments can be refunded.")
    expect(payment.reload).to be_refunded
  end

  it "rejects refunding a cancelled payment" do
    payment = create(:payment, status: :cancelled)

    result = described_class.call(payment: payment)

    expect(result.success?).to be false
    expect(result.error).to eq("Only paid payments can be refunded.")
    expect(payment.reload.status).to eq("cancelled")
  end

  it "rejects refunding a partial payment" do
    payment = create(:payment, status: :partial)

    result = described_class.call(payment: payment)

    expect(result.success?).to be false
    expect(payment.reload.status).to eq("partial")
  end
end
