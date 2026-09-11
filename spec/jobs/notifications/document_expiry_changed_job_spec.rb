require "rails_helper"

RSpec.describe Notifications::DocumentExpiryChangedJob do
  it "notifies the owner when the document is expiring soon" do
    folder = create(:library_folder)
    company = folder.company
    document = create(:library_document, folder: folder, company: company, expires_on: 5.days.from_now.to_date)

    expect { described_class.new.perform(document.id) }
      .to change { company.owner.notifications.where(kind: "document_expiring").count }.by(1)
  end

  it "does nothing when the document is inactive" do
    folder = create(:library_folder)
    document = create(:library_document, folder: folder, company: folder.company, expires_on: 5.days.from_now.to_date, active: false)

    expect { described_class.new.perform(document.id) }.not_to change(Notification, :count)
  end

  it "does nothing when the expiry date is outside the warning window" do
    folder = create(:library_folder)
    document = create(:library_document, folder: folder, company: folder.company, expires_on: 90.days.from_now.to_date)

    expect { described_class.new.perform(document.id) }.not_to change(Notification, :count)
  end

  it "does nothing when the document no longer exists" do
    expect { described_class.new.perform(SecureRandom.uuid) }.not_to change(Notification, :count)
  end
end
