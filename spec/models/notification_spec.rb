require "rails_helper"

RSpec.describe Notification do
  it "requires a known kind, a url and a dedup key" do
    expect(build(:notification, kind: "nope")).not_to be_valid
    expect(build(:notification, url: nil)).not_to be_valid
    expect(build(:notification, dedup_key: nil)).not_to be_valid
  end

  it "enforces one notification per (company, dedup_key)" do
    company = create(:company)
    create(:notification, company: company, dedup_key: "doc_exp:1")
    dup = build(:notification, company: company, recipient: company.owner, dedup_key: "doc_exp:1")
    expect(dup).not_to be_valid
  end

  it "scopes unread / recent" do
    company = create(:company)
    old = create(:notification, company: company, dedup_key: "a", read_at: 1.hour.ago)
    fresh = create(:notification, company: company, dedup_key: "b")
    expect(company.notifications.unread).to contain_exactly(fresh)
    expect(company.notifications.recent.first).to eq(fresh)
    expect(old.reload).to be_read
  end

  it "mark_read! is idempotent" do
    n = create(:notification)
    n.mark_read!
    first = n.read_at
    n.mark_read!
    expect(n.reload.read_at).to eq(first)
  end

  it "broadcasts to the recipient on create" do
    company = create(:company)
    expect {
      create(:notification, company: company, recipient: company.owner, dedup_key: "x")
    }.to have_broadcasted_to(company.owner).from_channel(NotificationChannel).at_least(:once)
  end
end
