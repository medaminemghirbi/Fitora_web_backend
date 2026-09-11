require "rails_helper"

RSpec.describe Client do
  let(:company) { create(:company) }

  it "downcases and strips the email before validation" do
    client = create(:client, company: company, email: "  Test@Example.COM ")
    expect(client.email).to eq("test@example.com")
  end

  it "defaults joined_at to now when not given" do
    travel_to(Time.zone.local(2026, 1, 1, 10, 0)) do
      client = create(:client, company: company, joined_at: nil)
      expect(client.joined_at).to eq(Time.zone.local(2026, 1, 1, 10, 0))
    end
  end

  it "requires first name, last name and phone" do
    client = build(:client, company: company, first_name: nil, last_name: nil, phone: nil)
    expect(client).not_to be_valid
    expect(client.errors[:first_name]).to be_present
    expect(client.errors[:last_name]).to be_present
    expect(client.errors[:phone]).to be_present
  end

  it "requires email uniqueness only once the client has a login password" do
    create(:client, company: company, email: "dup@example.com")
    dupe = build(:client, company: company, email: "dup@example.com")

    expect(dupe).to be_valid

    dupe.password = "password123"
    expect(dupe).not_to be_valid
    expect(dupe.errors[:email]).to be_present
  end

  it "requires a minimum password length only when a password is set" do
    client = build(:client, company: company, password: "short")
    expect(client).not_to be_valid
    expect(client.errors[:password]).to be_present
  end

  describe "#login_enabled?" do
    it "is only true once a password has been set" do
      client = create(:client, company: company)
      expect(client.login_enabled?).to be false

      client.update!(password: "password123")
      expect(client.login_enabled?).to be true
    end
  end

  it "builds the full name from first and last name" do
    client = build(:client, first_name: "Ahmed", last_name: "Ben Ali")
    expect(client.full_name).to eq("Ahmed Ben Ali")
  end

  describe ".active" do
    it "only returns active clients" do
      active = create(:client, company: company, active: true)
      inactive = create(:client, company: company, active: false)

      expect(Client.active).to include(active)
      expect(Client.active).not_to include(inactive)
    end
  end

  describe ".search" do
    it "matches by first name, last name, phone or email, case-insensitively" do
      match = create(:client, company: company, first_name: "Amine", last_name: "Trabelsi",
                               phone: "20111222", email: "amine@example.com")
      other = create(:client, company: company, first_name: "Sara", last_name: "Gharbi",
                               phone: "20333444", email: "sara@example.com")

      expect(Client.search("amine")).to contain_exactly(match)
      expect(Client.search("TRABELSI")).to contain_exactly(match)
    end

    it "returns everyone when the term is blank" do
      create_list(:client, 2, company: company)
      expect(Client.search("").count).to eq(2)
      expect(Client.search(nil).count).to eq(2)
    end
  end

  describe "#current_contract" do
    it "returns the contract whose current period is active and expires furthest out" do
      client = create(:client, company: company)
      create(:contract, client: client, contract_type: create(:contract_type, company: company),
                         status: :active, expires_at: 10.days.from_now)
      far = create(:contract, client: client, contract_type: create(:contract_type, company: company),
                               status: :active, expires_at: 30.days.from_now)

      expect(client.current_contract).to eq(far)
    end

    it "ignores contracts whose current period isn't active" do
      client = create(:client, company: company)
      create(:contract, client: client, contract_type: create(:contract_type, company: company), status: :cancelled)

      expect(client.current_contract).to be_nil
    end
  end

  describe "#outstanding_balance" do
    it "sums unpaid bookings and contract periods, net of payments already received" do
      client = create(:client, company: company)
      session = create(:session, activity: create(:activity, location: company.location))
      booking = create(:booking, client: client, session: session, amount: 20, payment_status: :unpaid)
      contract = create(:contract, client: client, contract_type: create(:contract_type, company: company, price: 89),
                                    status: :active, payment_status: :unpaid)

      expect(client.outstanding_balance).to eq(20 + 89)

      create(:payment, client: client, company: company, booking: booking, contract_period: nil,
                        amount: 20, status: :paid)
      create(:payment, client: client, company: company, contract_period: contract.contract_periods.first,
                        booking: nil, amount: 89, status: :paid)

      expect(client.reload.outstanding_balance).to eq(0)
    end

    it "never goes negative when payments exceed what's owed" do
      client = create(:client, company: company)
      session = create(:session, activity: create(:activity, location: company.location))
      booking = create(:booking, client: client, session: session, amount: 20, payment_status: :unpaid)
      create(:payment, client: client, company: company, booking: booking, contract_period: nil,
                        amount: 50, status: :paid)

      expect(client.outstanding_balance).to eq(0)
    end
  end

  describe "#attendance_rate" do
    it "returns nil when there is no attendance history" do
      client = create(:client, company: company)
      expect(client.attendance_rate).to be_nil
    end

    it "returns the percentage of bookings marked present, rounded" do
      client = create(:client, company: company)
      activity = create(:activity, location: company.location)
      b1 = create(:booking, client: client, session: create(:session, activity: activity))
      b2 = create(:booking, client: client, session: create(:session, activity: activity))
      b3 = create(:booking, client: client, session: create(:session, activity: activity))
      create(:attendance_record, booking: b1, status: :present)
      create(:attendance_record, booking: b2, status: :present)
      create(:attendance_record, booking: b3, status: :absent)

      expect(client.attendance_rate).to eq(67)
    end
  end
end
