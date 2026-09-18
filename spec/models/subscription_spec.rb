require "rails_helper"

RSpec.describe Subscription do
  describe "validations" do
    it "allows only one subscription per company" do
      company = create(:company)
      create(:subscription, company: company)

      duplicate = build(:subscription, company: company)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:company_id]).to be_present
    end

    it "rejects an upgrade_requested_period outside the known billing periods" do
      subscription = build(:subscription, upgrade_requested_period: "weekly")
      expect(subscription).not_to be_valid
      expect(subscription.errors[:upgrade_requested_period]).to be_present
    end

    it "allows a blank upgrade_requested_period" do
      expect(build(:subscription, upgrade_requested_period: nil)).to be_valid
    end
  end

  describe "#locked?" do
    it "is locked when the status isn't active" do
      subscription = build(:subscription, status: :cancelled)
      expect(subscription).to be_locked
    end

    it "is locked once expires_at has passed" do
      subscription = build(:subscription, status: :active, expires_at: 1.day.ago)
      expect(subscription).to be_locked
    end

    it "is not locked while active with no expiry or a future expiry" do
      expect(build(:subscription, status: :active, expires_at: nil)).not_to be_locked
      expect(build(:subscription, status: :active, expires_at: 1.day.from_now)).not_to be_locked
    end
  end

  describe "#days_remaining" do
    it "is nil when there is no expiry" do
      expect(build(:subscription, expires_at: nil).days_remaining).to be_nil
    end

    it "counts the days until expiry" do
      travel_to Time.zone.local(2026, 1, 1, 10, 0, 0) do
        subscription = build(:subscription, expires_at: Time.zone.local(2026, 1, 4, 9, 0, 0))
        expect(subscription.days_remaining).to eq(3)
      end
    end

    it "never returns a negative number once expired" do
      subscription = build(:subscription, expires_at: 5.days.ago)
      expect(subscription.days_remaining).to eq(0)
    end
  end

  describe "#on_trial?" do
    it "is true while no billing period has been set" do
      expect(build(:subscription, billing_period: nil)).to be_on_trial
    end

    it "is false once a billing period is set" do
      expect(build(:subscription, billing_period: :monthly)).not_to be_on_trial
    end
  end

  describe "#request_upgrade!" do
    it "records the request timestamp and the requested period" do
      subscription = create(:subscription)

      subscription.request_upgrade!(period: :yearly)

      expect(subscription.upgrade_requested_at).to be_present
      expect(subscription.upgrade_requested_period).to eq("yearly")
      expect(subscription).to be_upgrade_requested
    end

    it "drops an unrecognized period rather than persisting garbage" do
      subscription = create(:subscription)

      subscription.request_upgrade!(period: "bogus")

      expect(subscription.upgrade_requested_at).to be_present
      expect(subscription.upgrade_requested_period).to be_nil
    end
  end

  describe "#cancel_upgrade_request!" do
    it "clears the upgrade request" do
      subscription = create(:subscription)
      subscription.request_upgrade!(period: :monthly)

      subscription.cancel_upgrade_request!

      expect(subscription.upgrade_requested_at).to be_nil
      expect(subscription.upgrade_requested_period).to be_nil
      expect(subscription).not_to be_upgrade_requested
    end
  end

  describe "paying month by month" do
    # A gym on a real plan, settled through the end of this month.
    def paying(paid_through: Date.current.end_of_month, period: :monthly, status: :active)
      create(:subscription, billing_period: period, status: status,
                            expires_at: nil, paid_through: paid_through)
    end

    describe "#current_period_paid?" do
      it "is true while the paid period still covers today" do
        expect(paying.current_period_paid?).to be true
      end

      it "is false the day after the paid period ends" do
        subscription = paying(paid_through: Date.current.prev_day)
        expect(subscription.current_period_paid?).to be false
      end

      it "is false for a gym that has never paid" do
        expect(paying(paid_through: nil).current_period_paid?).to be false
      end
    end

    describe "the three days to settle" do
      it "does not lock a gym on the first day after its period ends" do
        subscription = paying(paid_through: Date.current.prev_day)

        expect(subscription).not_to be_payment_overdue
        expect(subscription.days_before_lock).to eq(2)
      end

      it "still does not lock on the third day" do
        subscription = paying(paid_through: Date.current - 3)

        expect(subscription).not_to be_payment_overdue
        expect(subscription.days_before_lock).to eq(0)
      end

      it "locks on the fourth" do
        subscription = paying(paid_through: Date.current - 4)

        expect(subscription).to be_payment_overdue
        expect(subscription.lock_reason).to eq(:payment_overdue)
        expect(subscription).to be_locked
      end

      it "leaves a trial alone — it has its own deadline" do
        trial = create(:subscription, billing_period: nil, status: :active,
                                      expires_at: 5.days.from_now, paid_through: nil)

        expect(trial).not_to be_payment_overdue
        expect(trial.days_before_lock).to be_nil
        expect(trial).not_to be_locked
      end

      it "reports nothing ticking while the period is still paid" do
        expect(paying.days_before_lock).to be_nil
      end
    end

    describe "#record_payment!" do
      it "covers the month that was missed rather than restarting from today" do
        subscription = paying(paid_through: Date.new(2026, 1, 31))

        travel_to(Date.new(2026, 3, 10)) { subscription.record_payment! }

        expect(subscription.paid_through).to eq(Date.new(2026, 2, 28))
      end

      it "stacks when a gym pays ahead" do
        subscription = paying(paid_through: Date.current.end_of_month)
        expected = subscription.paid_through >> 1

        subscription.record_payment!

        expect(subscription.paid_through).to eq(expected)
      end

      it "covers a year at a time on a yearly plan" do
        subscription = paying(paid_through: Date.new(2026, 12, 31), period: :yearly)

        travel_to(Date.new(2026, 6, 1)) { subscription.record_payment! }

        expect(subscription.paid_through).to eq(Date.new(2027, 12, 31))
      end

      it "settles the month in progress for a gym that has never paid" do
        subscription = paying(paid_through: nil)

        subscription.record_payment!

        expect(subscription.current_period_paid?).to be true
        expect(subscription).not_to be_payment_overdue
      end
    end

    describe "#undo_payment!" do
      it "takes back one period when a recorded payment never arrived" do
        subscription = paying(paid_through: Date.new(2026, 3, 31))

        travel_to(Date.new(2026, 3, 10)) { subscription.undo_payment! }

        expect(subscription.paid_through).to eq(Date.new(2026, 2, 28))
      end

      it "leaves the gym overdue rather than tidying the date away" do
        subscription = paying(paid_through: Date.current.end_of_month)

        subscription.undo_payment!

        expect(subscription.paid_through).to eq(Date.current.end_of_month << 1)
        expect(subscription.current_period_paid?).to be false
      end

      it "does nothing for a gym that never paid" do
        subscription = paying(paid_through: nil)
        subscription.undo_payment!
        expect(subscription.paid_through).to be_nil
      end
    end

    describe "#lock_reason" do
      it "puts an admin's own decision above anything owed" do
        subscription = paying(paid_through: Date.current - 10, status: :cancelled)
        expect(subscription.lock_reason).to eq(:suspended)
      end

      it "reports an expired trial as such, not as money owed" do
        trial = create(:subscription, billing_period: nil, status: :active, expires_at: 1.day.ago)
        expect(trial.lock_reason).to eq(:trial_expired)
      end

      it "is nil for a gym that is paid up" do
        expect(paying.lock_reason).to be_nil
      end
    end
  end
end
