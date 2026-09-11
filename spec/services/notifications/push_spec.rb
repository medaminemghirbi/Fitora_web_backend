require "rails_helper"

RSpec.describe Notifications::Push do
  let(:company) { create(:company) }
  let(:owner) { company.owner }

  def push(dedup: "doc_exp:1")
    described_class.call(
      recipient: owner, kind: "document_expiring", data: { "title" => "X" },
      url: "/owner/x", dedup_key: dedup
    )
  end

  it "creates a notification for the recipient" do
    expect { push }.to change(owner.notifications, :count).by(1)
  end

  it "is idempotent on the dedup key" do
    push
    expect { push }.not_to change(Notification, :count)
  end

  it "returns nil when the recipient is nil" do
    expect(described_class.call(recipient: nil, kind: "x", data: {}, url: "/", dedup_key: "k")).to be_nil
  end
end
