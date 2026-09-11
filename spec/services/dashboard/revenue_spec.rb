require "rails_helper"

RSpec.describe Dashboard::Revenue do
  def paid_payment(company, amount:, paid_at:)
    client = create(:client, company: company)
    plan = create(:contract_type, company: company)
    contract = create(:contract, client: client, contract_type: plan)

    create(:payment, company: company, client: client, contract_period: contract.current_period,
                      amount: amount, paid_at: paid_at, status: :paid)
  end

  it "buckets paid revenue into today, this week, this month, and a 14-day daily breakdown" do
    travel_to Time.zone.local(2025, 6, 18, 12, 0, 0) do
      company = create(:company)

      paid_payment(company, amount: 50, paid_at: Time.zone.local(2025, 6, 18, 10, 0, 0)) # today
      paid_payment(company, amount: 30, paid_at: Time.zone.local(2025, 6, 16, 10, 0, 0)) # this week, not today
      paid_payment(company, amount: 20, paid_at: Time.zone.local(2025, 6, 2, 10, 0, 0))  # this month, not this week
      paid_payment(company, amount: 999, paid_at: Time.zone.local(2025, 5, 1, 10, 0, 0)) # outside the month entirely

      result = described_class.call(company: company)

      expect(result[:today]).to eq(50)
      expect(result[:this_week]).to eq(80)
      expect(result[:this_month]).to eq(100)

      by_day_dates = result[:by_day].map { |d| d[:date].to_s }
      expect(by_day_dates).to include("2025-06-16", "2025-06-18")
      expect(by_day_dates).not_to include("2025-06-02", "2025-05-01")

      entry_for_16th = result[:by_day].find { |d| d[:date].to_s == "2025-06-16" }
      expect(entry_for_16th[:total]).to eq(30)
    end
  end

  it "only counts payments belonging to the given company" do
    travel_to Time.zone.local(2025, 6, 18, 12, 0, 0) do
      company = create(:company)
      other_company = create(:company)
      paid_payment(company, amount: 40, paid_at: Time.current)
      paid_payment(other_company, amount: 500, paid_at: Time.current)

      result = described_class.call(company: company)

      expect(result[:today]).to eq(40)
    end
  end

  it "returns zero totals and an empty daily breakdown for a company with no paid revenue" do
    company = create(:company)

    result = described_class.call(company: company)

    expect(result[:today]).to eq(0)
    expect(result[:this_week]).to eq(0)
    expect(result[:this_month]).to eq(0)
    expect(result[:by_day]).to eq([])
  end
end
