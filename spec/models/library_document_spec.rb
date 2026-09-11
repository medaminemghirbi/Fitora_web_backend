require "rails_helper"

RSpec.describe LibraryDocument do
  let(:sample_path) { Rails.root.join("spec/fixtures/files/sample.png") }

  it "requires the folder to belong to the same company" do
    document = build(:library_document, company: create(:company))

    expect(document).not_to be_valid
    expect(document.errors[:folder]).to be_present
  end

  it "requires a file to be attached" do
    document = build(:library_document)
    document.file.detach

    expect(document).not_to be_valid
    expect(document.errors[:file]).to be_present
  end

  it "rejects a disallowed file content type" do
    document = build(:library_document)
    document.file.attach(
      io: File.open(sample_path), filename: "virus.exe", content_type: "application/x-msdownload", identify: false
    )

    expect(document).not_to be_valid
    expect(document.errors[:file]).to be_present
  end

  it "rejects a file over the size ceiling" do
    document = build(:library_document)
    allow(document.file.blob).to receive(:byte_size).and_return(LibraryDocument::MAX_FILE_SIZE + 1)

    expect(document).not_to be_valid
    expect(document.errors[:file]).to be_present
  end

  describe "#expiring_soon?" do
    it "is true when expires_on falls within the next 30 days" do
      document = build(:library_document, expires_on: 5.days.from_now.to_date)
      expect(document).to be_expiring_soon
    end

    it "is false when expires_on is further out" do
      document = build(:library_document, expires_on: 90.days.from_now.to_date)
      expect(document).not_to be_expiring_soon
    end

    it "is false when there is no expiry date" do
      expect(build(:library_document, expires_on: nil)).not_to be_expiring_soon
    end
  end

  describe "#expired?" do
    it "is true once expires_on is in the past" do
      document = build(:library_document, expires_on: 1.day.ago.to_date)
      expect(document).to be_expired
    end

    it "is false for a future expiry date" do
      document = build(:library_document, expires_on: 1.day.from_now.to_date)
      expect(document).not_to be_expired
    end
  end

  describe ".active" do
    it "only returns active documents" do
      active = create(:library_document, active: true)
      inactive = create(:library_document, active: false)

      expect(LibraryDocument.active).to include(active)
      expect(LibraryDocument.active).not_to include(inactive)
    end
  end

  describe ".expiring_soon" do
    it "only returns documents expiring within the next 30 days, soonest first" do
      folder = create(:library_folder)
      soon = create(:library_document, folder: folder, company: folder.company, expires_on: 5.days.from_now.to_date)
      sooner = create(:library_document, folder: folder, company: folder.company, expires_on: 2.days.from_now.to_date)
      create(:library_document, folder: folder, company: folder.company, expires_on: 90.days.from_now.to_date)

      expect(LibraryDocument.expiring_soon).to eq([ sooner, soon ])
    end
  end

  describe "expiry notification callback" do
    it "enqueues a notification when created with an expiry date already inside the warning window" do
      document = build(:library_document, expires_on: 5.days.from_now.to_date)

      expect { document.save! }.to have_enqueued_job(Notifications::DocumentExpiryChangedJob).with(document.id)
    end

    it "does not enqueue a notification for an inactive document" do
      document = build(:library_document, expires_on: 5.days.from_now.to_date, active: false)

      expect { document.save! }.not_to have_enqueued_job(Notifications::DocumentExpiryChangedJob)
    end

    it "does not enqueue a notification when an unrelated field is updated" do
      document = create(:library_document, expires_on: 5.days.from_now.to_date)

      expect { document.update!(notes: "reviewed") }.not_to have_enqueued_job(Notifications::DocumentExpiryChangedJob)
    end
  end
end
