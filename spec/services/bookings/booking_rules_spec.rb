require "rails_helper"

# The configuration engine, doing something. These are the rules a company
# sets in CompanySettings, and the difference they make to a booking.
RSpec.describe "Booking rules driven by company settings" do
  let(:company) { create(:company) }
  let(:activity) { create(:activity, company: company) }
  let(:member) { create(:client, company: company) }

  def session_at(time, capacity: 10)
    create(:session, company: company, activity: activity, capacity: capacity,
                     starts_at: time, ends_at: time + 1.hour)
  end

  def subscribe!(client = member)
    plan = create(:contract_type, company: company, activity: activity)
    create(:contract, client: client, company: company, contract_type: plan, activity: activity)
  end

  describe "online_booking" do
    before { subscribe! }

    it "lets a member book themselves in when the gym allows it" do
      company.update!(settings: { features: { online_booking: true } })

      result = Bookings::Create.call(client: member, session: session_at(2.days.from_now), by: :member)

      expect(result).to be_success
    end

    it "turns a member away when the gym books for them instead" do
      company.update!(settings: { features: { online_booking: false } })

      result = Bookings::Create.call(client: member, session: session_at(2.days.from_now), by: :member)

      expect(result).not_to be_success
      expect(result.error).to match(/not available/i)
    end

    it "still lets the desk book them in — the rule is about self-booking" do
      company.update!(settings: { features: { online_booking: false } })

      result = Bookings::Create.call(client: member, session: session_at(2.days.from_now), by: :staff)

      expect(result).to be_success
    end
  end

  describe "booking_opens_days" do
    before { subscribe! }

    it "refuses a member booking further ahead than the gym opens" do
      company.update!(settings: { booking: { booking_opens_days: 7 } })

      result = Bookings::Create.call(client: member, session: session_at(30.days.from_now), by: :member)

      expect(result).not_to be_success
      expect(result.error).to include("7 days")
    end

    it "allows one inside the window" do
      company.update!(settings: { booking: { booking_opens_days: 7 } })

      result = Bookings::Create.call(client: member, session: session_at(3.days.from_now), by: :member)

      expect(result).to be_success
    end

    it "does not apply to the desk" do
      company.update!(settings: { booking: { booking_opens_days: 7 } })

      result = Bookings::Create.call(client: member, session: session_at(30.days.from_now), by: :staff)

      expect(result).to be_success
    end
  end

  describe "cancellation_hours" do
    let(:booking) do
      subscribe!
      Bookings::Create.call(client: member, session: session_at(3.hours.from_now), by: :staff).booking
    end

    it "lets a member cancel outside the window" do
      company.update!(settings: { booking: { cancellation_hours: 2 } })

      result = Bookings::Cancel.call(booking: booking, by: :member)

      expect(result).to be_success
      expect(booking.reload).to be_cancelled
    end

    it "refuses a member cancelling inside it" do
      company.update!(settings: { booking: { cancellation_hours: 12 } })

      result = Bookings::Cancel.call(booking: booking, by: :member)

      expect(result).not_to be_success
      expect(result.error).to include("12 hours")
      expect(booking.reload).to be_confirmed
    end

    it "lets the desk cancel regardless — they have to be able to fix things" do
      company.update!(settings: { booking: { cancellation_hours: 12 } })

      result = Bookings::Cancel.call(booking: booking, by: :staff)

      expect(result).to be_success
    end

    it "allows cancelling right up to the start when the window is zero" do
      company.update!(settings: { booking: { cancellation_hours: 0 } })

      expect(Bookings::Cancel.call(booking: booking, by: :member)).to be_success
    end

    it "gives the session's credit back on a cancellation" do
      company.update!(settings: { booking: { cancellation_hours: 0 } })
      contract = subscribe!
      contract.contract_type.update!(unlimited_bookings: false, session_count: 10)
      contract.current_period.update!(remaining_bookings: 5)
      booked = Bookings::Create.call(client: member, session: session_at(4.hours.from_now), by: :staff).booking

      expect { Bookings::Cancel.call(booking: booked, by: :member) }
        .to change { contract.current_period.reload.remaining_bookings }.by(1)
    end
  end

  describe "the waitlist" do
    let!(:full_session) { session_at(2.days.from_now, capacity: 1) }
    let(:other) { create(:client, company: company) }

    before do
      subscribe!
      subscribe!(other)
      create(:membership, client: other, company: company) unless other.companies.include?(company)
      Bookings::Create.call(client: other, session: full_session, by: :staff)
    end

    it "says the session is full when the gym runs no queue" do
      company.update!(settings: { features: { waitlist: false } })

      result = Bookings::Create.call(client: member, session: full_session, by: :staff)

      expect(result).not_to be_success
      expect(result.error).to eq("This session is full.")
    end

    it "puts them in the queue when it does" do
      company.update!(settings: { features: { waitlist: true } })

      result = Bookings::Create.call(client: member, session: full_session, by: :staff)

      expect(result).to be_success
      expect(result.waitlisted).to be(true)
      expect(result.booking).to be_waitlisted
      expect(result.booking.waitlist_position).to eq(1)
    end

    it "does not spend a session credit on a place in the queue" do
      company.update!(settings: { features: { waitlist: true } })
      contract = member.contracts.first
      contract.contract_type.update!(unlimited_bookings: false, session_count: 10)
      contract.current_period.update!(remaining_bookings: 5)

      expect { Bookings::Create.call(client: member, session: full_session, by: :staff) }
        .not_to change { contract.current_period.reload.remaining_bookings }
    end

    it "keeps a queue in the order people joined it" do
      company.update!(settings: { features: { waitlist: true } })
      third = create(:client, company: company)
      subscribe!(third)

      first = Bookings::Create.call(client: member, session: full_session, by: :staff).booking
      second = Bookings::Create.call(client: third, session: full_session, by: :staff).booking

      expect([ first.waitlist_position, second.waitlist_position ]).to eq([ 1, 2 ])
    end

    it "promotes the first in line when a seat frees up" do
      company.update!(settings: { features: { waitlist: true } })
      queued = Bookings::Create.call(client: member, session: full_session, by: :staff).booking
      seat = full_session.bookings.confirmed.first

      Bookings::Cancel.call(booking: seat, by: :staff)

      expect(queued.reload).to be_confirmed
      expect(queued.waitlist_position).to be_nil
    end

    it "promotes nobody when the gym has no queue" do
      company.update!(settings: { features: { waitlist: false } })
      seat = full_session.bookings.confirmed.first

      result = Bookings::Cancel.call(booking: seat, by: :staff)

      expect(result).to be_success
      expect(result.promoted).to be_nil
    end

    it "closes the gap in the queue after a promotion" do
      company.update!(settings: { features: { waitlist: true } })
      third = create(:client, company: company)
      subscribe!(third)
      Bookings::Create.call(client: member, session: full_session, by: :staff)
      behind = Bookings::Create.call(client: third, session: full_session, by: :staff).booking

      Bookings::Cancel.call(booking: full_session.bookings.confirmed.first, by: :staff)

      expect(behind.reload.waitlist_position).to eq(1)
    end

    it "refuses a queue place to somebody with no contract" do
      company.update!(settings: { features: { waitlist: true } })
      stranger = create(:client, company: company)

      result = Bookings::Create.call(client: stranger, session: full_session, by: :staff)

      expect(result).not_to be_success
      expect(result.error).to match(/active contract/i)
    end
  end
end
