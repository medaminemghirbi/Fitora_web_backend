require "rails_helper"

RSpec.describe Bookings::Create do
  # Every booking is now settled against the member's contract, so a client
  # needs a plan covering the session's company before they can book.
  def contract_for(client, session)
    plan = create(:contract_type, company: session.location.company, unlimited_bookings: true)
    create(:contract, client: client, contract_type: plan)
  end

  it "confirms a booking when the client has a covering contract and capacity is available" do
    session = create(:session, capacity: 2)
    client = create(:client)
    contract_for(client, session)

    result = described_class.call(client: client, session: session)

    expect(result.success?).to be true
    expect(result.booking).to be_confirmed
    expect(result.booking.contract_period).to be_present
  end

  it "rejects a booking when the client has no covering contract" do
    session = create(:session, capacity: 2)
    client = create(:client)

    result = described_class.call(client: client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This client needs an active contract to book this activity.")
  end

  it "rejects a booking once the session is full" do
    session = create(:session, capacity: 1)
    create(:booking, session: session, status: :confirmed)
    client = create(:client)

    result = described_class.call(client: client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This session is full.")
  end

  it "rejects a duplicate booking by the same client" do
    session = create(:session, capacity: 5)
    client = create(:client)
    create(:booking, session: session, client: client, status: :confirmed)

    result = described_class.call(client: client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This client already has a booking for this session.")
  end

  it "rejects booking a cancelled session" do
    session = create(:session, status: :cancelled)
    client = create(:client)

    result = described_class.call(client: client, session: session)

    expect(result.success?).to be false
    expect(result.error).to eq("This session has been cancelled.")
  end

  it "does not allow bookings to exceed capacity under concurrent requests" do
    session = create(:session, capacity: 1)
    client_a = create(:client)
    client_b = create(:client)
    contract_for(client_a, session)
    contract_for(client_b, session)

    results = [ client_a, client_b ].map do |client|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.call(client: client, session: session)
        end
      end
    end.map(&:value)

    successes = results.count(&:success?)
    expect(successes).to eq(1)
    expect(session.reload.confirmed_bookings_count).to eq(1)
  end

  it "does not let a contract's booking credit go negative under concurrent requests against different sessions" do
    company = create(:company)
    client = create(:client, company: company)
    plan = create(:contract_type, company: company, unlimited_bookings: false, booking_limit: 1)
    contract = create(:contract, client: client, contract_type: plan, remaining_bookings: 1)
    session_a = create(:session, activity: create(:activity, location: company.locations.first), capacity: 5)
    session_b = create(:session, activity: session_a.activity, location: session_a.location, capacity: 5)

    results = [ session_a, session_b ].map do |session|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          described_class.call(client: client, session: session)
        end
      end
    end.map(&:value)

    successes = results.count(&:success?)
    expect(successes).to eq(1)
    expect(contract.current_period.reload.remaining_bookings).to eq(0)
  end
end
