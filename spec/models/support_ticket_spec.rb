require "rails_helper"

RSpec.describe SupportTicket, type: :model do
  let(:sample_path) { Rails.root.join("spec/fixtures/files/sample.png") }

  describe "the number to call back on a plan request" do
    it "is required on a plan request" do
      ticket = build(:support_ticket, kind: :upgrade, contact_phone: "  ")
      expect(ticket).not_to be_valid
      expect(ticket.errors[:contact_phone]).to be_present
    end

    it "is optional on any other ticket" do
      expect(build(:support_ticket, contact_phone: nil)).to be_valid
    end

    it "takes the usual ways of writing a number" do
      [ "+216 22 123 456", "22123456", "(+33) 6.12.34.56.78", "06-12-34-56-78" ].each do |phone|
        expect(build(:support_ticket, kind: :upgrade, contact_phone: phone)).to be_valid, phone
      end
    end

    it "refuses what is not a number, or too short to be one" do
      [ "appelez-moi", "1234", "+216 22 abc 456" ].each do |phone|
        expect(build(:support_ticket, kind: :upgrade, contact_phone: phone)).not_to be_valid, phone
      end
    end
  end

  it "rejects a disallowed attachment content type" do
    ticket = build(:support_ticket)
    ticket.attachments.attach(
      io: File.open(sample_path), filename: "virus.exe", content_type: "application/x-msdownload", identify: false
    )

    expect(ticket).not_to be_valid
    expect(ticket.errors[:attachments]).to be_present
  end

  it "rejects more than MAX_ATTACHMENTS files" do
    ticket = build(:support_ticket)
    (SupportTicket::MAX_ATTACHMENTS + 1).times do |n|
      ticket.attachments.attach(io: File.open(sample_path), filename: "file#{n}.png", content_type: "image/png")
    end

    expect(ticket).not_to be_valid
    expect(ticket.errors[:attachments]).to be_present
  end

  it "accepts an allowed image attachment" do
    ticket = build(:support_ticket)
    ticket.attachments.attach(io: File.open(sample_path), filename: "screenshot.png", content_type: "image/png")

    expect(ticket).to be_valid
  end

  it "is valid with no attachments at all" do
    expect(build(:support_ticket)).to be_valid
  end
end
