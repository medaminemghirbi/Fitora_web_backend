require "rails_helper"

RSpec.describe Dashboard::Statistics do
  it "counts clients, active contracts, and today's schedule activity" do
    company = create(:company)
    create(:client, company: company, active: true)
    create(:client, company: company, active: false)

    plan = create(:contract_type, company: company)
    member = create(:client, company: company)
    create(:contract, client: member, contract_type: plan)

    activity = create(:activity, company: company, name: "Yoga")
    session = create(:session, activity: activity, company: company,
                                starts_at: Time.current.change(hour: 9), ends_at: Time.current.change(hour: 10),
                                capacity: 5)
    booking = create(:booking, session: session, client: member, status: :confirmed)
    create(:attendance_record, booking: booking, status: :present)

    result = described_class.call(company: company)

    expect(result[:total_clients]).to eq(2)
    expect(result[:active_contracts]).to eq(1)
    expect(result[:todays_bookings]).to eq(1)
    expect(result[:todays_attendance]).to eq(1)

    expect(result[:todays_schedule].size).to eq(1)
    schedule_entry = result[:todays_schedule].first
    expect(schedule_entry[:id]).to eq(session.id)
    expect(schedule_entry[:activity_name]).to eq("Yoga")
    expect(schedule_entry[:confirmed_count]).to eq(1)
    expect(schedule_entry[:capacity]).to eq(5)
    expect(schedule_entry[:status]).to eq("scheduled")
  end

  it "computes outstanding payments from unpaid bookings and unpaid contract periods" do
    company = create(:company)
    plan = create(:contract_type, company: company, price: 150)
    client = create(:client, company: company)
    create(:contract, client: client, contract_type: plan, discount: 20) # final_price 130, unpaid

    activity = create(:activity, company: company)
    session = create(:session, activity: activity, company: company, price: 45)
    create(:booking, session: session, client: client, amount: 45, payment_status: :unpaid)

    result = described_class.call(company: company)

    expect(result[:outstanding_payments]).to eq(175)
  end

  it "lists contracts expiring within the notification window" do
    company = create(:company)
    plan = create(:contract_type, company: company, name: "Plan A")
    soon_client = create(:client, company: company, first_name: "Amina", last_name: "Trabelsi")
    expiring_contract = create(:contract, client: soon_client, contract_type: plan, status: :active,
                                           expires_at: 3.days.from_now)

    far_client = create(:client, company: company)
    create(:contract, client: far_client, contract_type: plan, status: :active, expires_at: 20.days.from_now)

    result = described_class.call(company: company)

    expect(result[:contracts_expiring].size).to eq(1)
    entry = result[:contracts_expiring].first
    expect(entry[:id]).to eq(expiring_contract.id)
    expect(entry[:client_name]).to eq("Amina Trabelsi")
    expect(entry[:plan_name]).to eq("Plan A")
  end

  it "lists recent payments and recent clients" do
    company = create(:company)
    plan = create(:contract_type, company: company)

    client_a = create(:client, company: company, first_name: "Amina")
    period_a = create(:contract, client: client_a, contract_type: plan).current_period
    create(:payment, company: company, client: client_a, contract_period: period_a, amount: 60, status: :paid)

    client_b = create(:client, company: company, first_name: "Youssef")
    period_b = create(:contract, client: client_b, contract_type: plan).current_period
    create(:payment, company: company, client: client_b, contract_period: period_b, amount: 40, status: :paid)

    result = described_class.call(company: company)

    expect(result[:recent_payments].size).to eq(2)
    expect(result[:recent_payments].map { |p| p[:client_name] }).to contain_exactly("Amina Ben Ali", "Youssef Ben Ali")
    expect(result[:recent_clients].map { |c| c[:full_name] }).to contain_exactly("Amina Ben Ali", "Youssef Ben Ali")
  end
end
