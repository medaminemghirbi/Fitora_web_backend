require "rails_helper"

RSpec.describe LeaveRequest do
  it "computes days_count from the company's working days when not provided" do
    company = create(:company) # default working_days is Mon-Fri
    staff_member = create(:staff_member, company: company)
    absence_type = create(:absence_type, company: company)
    leave = build(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type,
                                   starts_on: Date.new(2025, 3, 3), ends_on: Date.new(2025, 3, 9), days_count: nil)

    leave.valid?

    expect(leave.days_count).to eq(5) # Mon 3 - Fri 7, excludes the weekend
  end

  it "does not override an explicitly provided days_count" do
    company = create(:company)
    staff_member = create(:staff_member, company: company)
    absence_type = create(:absence_type, company: company)
    leave = build(:leave_request, company: company, staff_member: staff_member, absence_type: absence_type,
                                   starts_on: Date.new(2025, 3, 3), ends_on: Date.new(2025, 3, 9), days_count: 1)

    leave.valid?

    expect(leave.days_count).to eq(1)
  end

  it "rejects an end date before the start date" do
    leave = build(:leave_request, starts_on: Date.new(2025, 3, 10), ends_on: Date.new(2025, 3, 5))

    expect(leave).not_to be_valid
    expect(leave.errors[:ends_on]).to be_present
  end

  it "rejects an absence type belonging to a different company" do
    leave = build(:leave_request, absence_type: create(:absence_type))

    expect(leave).not_to be_valid
    expect(leave.errors[:absence_type]).to be_present
  end

  describe ".in_year" do
    it "only returns leave requests starting in the given year" do
      company = create(:company)
      in_2025 = create(:leave_request, company: company, starts_on: Date.new(2025, 1, 5), ends_on: Date.new(2025, 1, 6))
      in_2024 = create(:leave_request, company: company, starts_on: Date.new(2024, 6, 1), ends_on: Date.new(2024, 6, 2))

      expect(LeaveRequest.in_year(2025)).to include(in_2025)
      expect(LeaveRequest.in_year(2025)).not_to include(in_2024)
    end
  end

  describe ".recent_first" do
    it "orders by starts_on descending" do
      company = create(:company)
      earlier = create(:leave_request, company: company, starts_on: Date.new(2025, 1, 1), ends_on: Date.new(2025, 1, 2))
      later = create(:leave_request, company: company, starts_on: Date.new(2025, 6, 1), ends_on: Date.new(2025, 6, 2))

      expect(company.leave_requests.recent_first).to eq([ later, earlier ])
    end
  end

  describe ".counts_against_balance" do
    it "only includes approved leave using a paid absence type" do
      company = create(:company)
      paid_type = create(:absence_type, company: company, paid: true)
      unpaid_type = create(:absence_type, company: company, paid: false)

      approved_paid = create(:leave_request, company: company, absence_type: paid_type, status: :approved)
      create(:leave_request, company: company, absence_type: unpaid_type, status: :approved)
      create(:leave_request, company: company, absence_type: paid_type, status: :pending)

      expect(LeaveRequest.counts_against_balance).to contain_exactly(approved_paid)
    end
  end
end
