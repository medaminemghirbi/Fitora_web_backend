require "rails_helper"

RSpec.describe Subscription do
  let(:company) { create(:company) }

  def paid_until(date, period: :monthly)
    subscription = create(:subscription, company: company, billing_period: period)
    create(:invoice, company: company, period_start: date - 30, period_end: date, billing_period: period)
    subscription.reload
  end

  it "belongs to exactly one company" do
    create(:subscription, company: company)
    expect(build(:subscription, company: company)).not_to be_valid
  end

  describe "#active — the access itself" do
    it "is what locked? reads, with nothing computed" do
      expect(create(:subscription, company: company)).not_to be_locked
      expect(create(:subscription, :closed, company: create(:company))).to be_locked
    end

    it "suspends and restores" do
      subscription = create(:subscription, company: company)

      subscription.suspend!
      expect(subscription.reload).to be_locked

      subscription.restore!
      expect(subscription.reload).not_to be_locked
    end
  end

  describe "what the invoices say" do
    it "reads paid_through from the latest invoice" do
      subscription = paid_until(Date.new(2026, 9, 30))
      expect(subscription.paid_through).to eq(Date.new(2026, 9, 30))
    end

    it "has no paid_through at all before the first invoice" do
      subscription = create(:subscription, company: company)
      expect(subscription.paid_through).to be_nil
      expect(subscription).not_to be_current_period_paid
    end

    it "takes the latest period, not the last row created" do
      subscription = create(:subscription, company: company)
      create(:invoice, company: company, period_start: Date.current, period_end: Date.current + 20)
      create(:invoice, company: company, period_start: Date.current - 60, period_end: Date.current - 30)

      expect(subscription.reload.paid_through).to eq(Date.current + 20)
    end
  end

  describe "the three days to settle" do
    it "is not uncovered on the first day after the period ends" do
      subscription = paid_until(Date.current.prev_day)
      expect(subscription).not_to be_uncovered
      expect(subscription.days_before_lock).to eq(2)
    end

    it "is still not uncovered on the third day" do
      subscription = paid_until(Date.current - 3)
      expect(subscription).not_to be_uncovered
      expect(subscription.days_before_lock).to eq(0)
    end

    it "is uncovered on the fourth" do
      subscription = paid_until(Date.current - 4)
      expect(subscription).to be_uncovered
    end

    it "reports nothing ticking while the period is still paid" do
      expect(paid_until(Date.current.end_of_month).days_before_lock).to be_nil
    end

    it "treats a gym that never paid as uncovered" do
      expect(create(:subscription, company: company)).to be_uncovered
    end
  end

  describe "#lock_reason — two words, never four" do
    it "is nil while access is open" do
      expect(paid_until(Date.current.end_of_month).lock_reason).to be_nil
    end

    it "says unpaid when the invoices ran out" do
      subscription = paid_until(Date.current - 10)
      subscription.suspend!
      expect(subscription.lock_reason).to eq(:unpaid)
    end

    it "says suspended when a paid-up gym was closed by hand" do
      subscription = paid_until(Date.current.end_of_month)
      subscription.suspend!
      expect(subscription.lock_reason).to eq(:suspended)
    end
  end

  describe "#next_period — what an invoice would cover" do
    it "starts the day after the last one ended" do
      subscription = paid_until(Date.new(2026, 8, 31))
      expect(subscription.next_period).to eq(Date.new(2026, 9, 1)..Date.new(2026, 9, 30))
    end

    it "starts today for a gym with no history" do
      subscription = create(:subscription, company: company)
      expect(subscription.next_period.first).to eq(Date.current)
    end

    it "covers a year on a yearly plan" do
      subscription = paid_until(Date.new(2026, 12, 31), period: :yearly)
      expect(subscription.next_period).to eq(Date.new(2027, 1, 1)..Date.new(2027, 12, 31))
    end
  end

  describe "#arrears_cents — owed, never typed in" do
    it "is zero while the period is paid" do
      expect(paid_until(Date.current.end_of_month).arrears_cents).to eq(0)
    end

    it "counts the months with no invoice behind them" do
      subscription = paid_until(Date.current.prev_month.end_of_month)
      expect(subscription.arrears_cents).to eq(company.monthly_subscription_cents)
    end
  end
end
