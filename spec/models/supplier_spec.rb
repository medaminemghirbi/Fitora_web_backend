require "rails_helper"

RSpec.describe Supplier do
  it "rejects a malformed email" do
    supplier = build(:supplier, email: "not-an-email")
    expect(supplier).not_to be_valid
    expect(supplier.errors[:email]).to be_present
  end

  it "allows a blank email" do
    expect(build(:supplier, email: nil)).to be_valid
  end

  describe "photo validation" do
    let(:sample_path) { Rails.root.join("spec/fixtures/files/sample.png") }

    it "rejects a disallowed photo content type" do
      supplier = build(:supplier)
      supplier.photo.attach(
        io: File.open(sample_path), filename: "virus.exe", content_type: "application/x-msdownload", identify: false
      )

      expect(supplier).not_to be_valid
      expect(supplier.errors[:photo]).to be_present
    end

    it "rejects a photo over the size ceiling" do
      supplier = build(:supplier)
      supplier.photo.attach(io: File.open(sample_path), filename: "photo.png", content_type: "image/png")
      allow(supplier.photo.blob).to receive(:byte_size).and_return(HasPhoto::MAX_PHOTO_SIZE + 1)

      expect(supplier).not_to be_valid
      expect(supplier.errors[:photo]).to be_present
    end

    it "is valid with no photo attached" do
      expect(build(:supplier)).to be_valid
    end
  end

  describe ".active" do
    it "only returns active suppliers" do
      active = create(:supplier, active: true)
      inactive = create(:supplier, active: false)

      expect(Supplier.active).to include(active)
      expect(Supplier.active).not_to include(inactive)
    end
  end

  describe ".search" do
    it "matches on name, category, contact_name, phone, or email" do
      company = create(:company)
      match = create(:supplier, company: company, name: "Aqua Fitness", category: "Piscine", contact_name: "Sami",
                                 phone: "12345678", email: "sami@aqua.tn")
      create(:supplier, company: company, name: "Autre fournisseur", category: "Textile", contact_name: "Nour",
                         phone: "99999999", email: "nour@autre.tn")

      expect(Supplier.search("aqua")).to contain_exactly(match)
    end

    it "returns everything when the term is blank" do
      create_list(:supplier, 2)
      expect(Supplier.search("")).to eq(Supplier.all)
    end
  end
end
