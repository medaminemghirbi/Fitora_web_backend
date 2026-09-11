require "rails_helper"

RSpec.describe Notifications::ContractExpiryChangedJob do
  it "notifies the owner when the period is expiring soon" do
    contract = create(:contract, expires_at: 5.days.from_now)
    period = contract.contract_periods.last
    company = contract.company

    expect { described_class.new.perform(period.id) }
      .to change { company.owner.notifications.where(kind: "contract_expiring").count }.by(1)
  end

  it "does nothing when the period is not within the warning window" do
    contract = create(:contract, expires_at: 60.days.from_now)
    period = contract.contract_periods.last

    expect { described_class.new.perform(period.id) }.not_to change(Notification, :count)
  end

  it "does nothing when the period is not active" do
    contract = create(:contract, status: :pending, expires_at: 5.days.from_now)
    period = contract.contract_periods.last

    expect { described_class.new.perform(period.id) }.not_to change(Notification, :count)
  end

  it "does nothing when the period no longer exists" do
    expect { described_class.new.perform(SecureRandom.uuid) }.not_to change(Notification, :count)
  end
end
