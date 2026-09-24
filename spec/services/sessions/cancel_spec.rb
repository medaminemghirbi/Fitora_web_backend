require "rails_helper"

RSpec.describe Sessions::Cancel do
  let(:company) { create(:company) }
  let(:activity) { create(:activity, company: company) }
  let(:session) { create(:session, activity: activity, capacity: 1) }
  let(:plan) { create(:contract_type, company: company, activity: activity, unlimited_bookings: false) }

  def member_with_credits(credits)
    client = create(:client, company: company)
    contract = create(:contract, client: client, contract_type: plan, activity: activity, remaining_bookings: credits)
    [ client, contract ]
  end

  it "cancels every seat on it and gives each member their session back" do
    client, contract = member_with_credits(5)
    result = Bookings::Create.call(client: client, session: session)
    expect(contract.current_period.reload.remaining_bookings).to eq(4)

    outcome = described_class.call(session: session)

    expect(outcome.success?).to be(true)
    expect(outcome.cancelled_bookings).to eq(1)
    expect(result.booking.reload).to be_cancelled
    expect(contract.current_period.reload.remaining_bookings).to eq(5)
  end

  it "empties the queue without handing out sessions nobody spent" do
    company.update!(settings: { features: { waitlist: true } })
    seated, = member_with_credits(5)
    queued, queued_contract = member_with_credits(5)
    Bookings::Create.call(client: seated, session: session)
    waiting = Bookings::Create.call(client: queued, session: session)
    expect(waiting.waitlisted).to be(true)

    described_class.call(session: session)

    expect(waiting.booking.reload).to be_cancelled
    expect(queued_contract.current_period.reload.remaining_bookings).to eq(5)
  end

  it "refuses a session already cancelled" do
    session.update!(status: :cancelled)

    expect(described_class.call(session: session).success?).to be(false)
  end
end

RSpec.describe Bookings::Cancel do
  it "gives nothing back for leaving a queue that cost nothing" do
    company = create(:company)
    company.update!(settings: { features: { waitlist: true } })
    activity = create(:activity, company: company)
    session = create(:session, activity: activity, capacity: 1)
    plan = create(:contract_type, company: company, activity: activity, unlimited_bookings: false)
    seated = create(:client, company: company)
    create(:contract, client: seated, contract_type: plan, activity: activity, remaining_bookings: 3)
    queued = create(:client, company: company)
    contract = create(:contract, client: queued, contract_type: plan, activity: activity, remaining_bookings: 3)
    Bookings::Create.call(client: seated, session: session)
    waiting = Bookings::Create.call(client: queued, session: session).booking

    described_class.call(booking: waiting)

    expect(contract.current_period.reload.remaining_bookings).to eq(3)
  end
end
