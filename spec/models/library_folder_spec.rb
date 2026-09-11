require "rails_helper"

RSpec.describe LibraryFolder do
  it "rejects a duplicate name within the same company" do
    company = create(:company)
    create(:library_folder, company: company, name: "Contrats")
    duplicate = build(:library_folder, company: company, name: "Contrats")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "allows the same name in a different company" do
    create(:library_folder, name: "Contrats")
    other_company_folder = build(:library_folder, name: "Contrats")

    expect(other_company_folder).to be_valid
  end

  it "destroys its documents when the folder is destroyed" do
    folder = create(:library_folder)
    document = create(:library_document, folder: folder, company: folder.company)

    folder.destroy

    expect(LibraryDocument.exists?(document.id)).to be false
  end
end
