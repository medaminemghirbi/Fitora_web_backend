require "rails_helper"

RSpec.describe "Notifications daily scans" do
  describe Notifications::ScanExpiringDocumentsJob do
    it "notifies the owner once per expiring document, idempotently" do
      folder = create(:library_folder)
      company = folder.company
      create(:library_document, folder: folder, company: company, expires_on: 5.days.from_now.to_date)
      create(:library_document, folder: folder, company: company, expires_on: 90.days.from_now.to_date) # outside window

      expect { described_class.new.perform }.to change { company.owner.notifications.where(kind: "document_expiring").count }.by(1)
      expect { described_class.new.perform }.not_to change(Notification, :count)
    end
  end

  describe Notifications::ScanExpiringContractsJob do
    it "notifies the owner for a period expiring within the window" do
      contract = create(:contract, expires_at: 5.days.from_now)
      company = contract.company

      expect { described_class.new.perform }.to change { company.owner.notifications.where(kind: "contract_expiring").count }.by(1)
    end

    it "ignores periods expiring far out" do
      create(:contract, expires_at: 60.days.from_now)
      expect { described_class.new.perform }.not_to change(Notification, :count)
    end
  end

  describe Notifications::ScanEmployeeBirthdaysJob do
    it "notifies the owner for a coach whose birthday is today" do
      company = create(:company)
      create(:coach, company: company, birthdate: Date.new(1990, Date.current.month, Date.current.day))
      create(:coach, company: company, birthdate: Date.current - 100.days)

      expect { described_class.new.perform }.to change { company.owner.notifications.where(kind: "employee_birthday").count }.by(1)
      expect { described_class.new.perform }.not_to change(Notification, :count) # once per year
    end
  end
end
