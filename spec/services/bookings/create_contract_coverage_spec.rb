require "rails_helper"

RSpec.describe "Bookings::Create — contract coverage" do
  it "confirms instantly and consumes a booking credit when the client has a covering contract" do
    session = create(:session, capacity: 5)
    plan = create(:contract_type, company: session.company, unlimited_bookings: false, booking_limit: 3)
    contract = create(:contract, contract_type: plan, activity: session.activity, remaining_bookings: 3)

    result = Bookings::Create.call(client: contract.client, session: session)

    expect(result.success?).to be true
    expect(result.booking).to be_confirmed
    expect(result.booking.contract_period.contract).to eq(contract)
    expect(result.booking).to be_paid
    expect(result.booking.amount).to eq(0)
    expect(contract.reload.remaining_bookings).to eq(2)
  end

  it "confirms without touching a credit when the plan has unlimited bookings" do
    session = create(:session, capacity: 5)
    plan = create(:contract_type, company: session.company, unlimited_bookings: true)
    contract = create(:contract, contract_type: plan, activity: session.activity)

    result = Bookings::Create.call(client: contract.client, session: session)

    expect(result.success?).to be true
    expect(result.booking).to be_confirmed
  end

  it "rejects the booking with a friendly error when there is no covering contract" do
    session = create(:session, capacity: 5)
    client = create(:client)

    result = Bookings::Create.call(client: client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This client needs an active contract to book this activity.")
  end

  it "rejects a booking when the plan's credits are exhausted" do
    session = create(:session, capacity: 5)
    plan = create(:contract_type, company: session.company, unlimited_bookings: false, booking_limit: 1)
    contract = create(:contract, contract_type: plan, remaining_bookings: 0)

    result = Bookings::Create.call(client: contract.client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This client needs an active contract to book this activity.")
  end

  it "does not grant access from a contract plan scoped to a different activity — even when the contract's own activity matches the session" do
    session = create(:session, capacity: 5)
    other_activity = create(:activity, company: session.company)
    plan = create(:contract_type, company: session.company, unlimited_bookings: true, activity: other_activity)
    contract = create(:contract, contract_type: plan, activity: session.activity)
    # The plan is sold for other_activity only: dropping the grid row is what
    # "this plan isn't offered for that activity" now means.
    plan.contract_type_activities.find_by(activity: session.activity).destroy

    result = Bookings::Create.call(client: contract.client, session: session)

    expect(result.success?).to be false
  end
end
