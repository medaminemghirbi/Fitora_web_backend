require "rails_helper"

RSpec.describe Salle do
  it "requires a name" do
    salle = build(:salle, name: nil)

    expect(salle).not_to be_valid
    expect(salle.errors[:name]).to be_present
  end

  it "requires a positive integer capacity" do
    expect(build(:salle, capacity: 0)).not_to be_valid
    expect(build(:salle, capacity: -1)).not_to be_valid
    expect(build(:salle, capacity: 1.5)).not_to be_valid
    expect(build(:salle, capacity: 20)).to be_valid
  end

  it "delegates company to its location" do
    location = create(:location)
    salle = create(:salle, location: location)

    expect(salle.company).to eq(location.company)
  end

  describe ".active" do
    it "only returns active salles" do
      active = create(:salle, active: true)
      inactive = create(:salle, active: false)

      expect(Salle.active).to include(active)
      expect(Salle.active).not_to include(inactive)
    end
  end

  describe "image gallery (HasPhotos)" do
    let(:sample_path) { Rails.root.join("spec/fixtures/files/sample.png") }

    it "is valid with no images attached" do
      expect(build(:salle)).to be_valid
    end

    it "accepts allowed image types" do
      salle = build(:salle)
      salle.images.attach(io: File.open(sample_path), filename: "room.png", content_type: "image/png")

      expect(salle).to be_valid
    end

    it "rejects a non-image file" do
      salle = build(:salle)
      salle.images.attach(io: File.open(Rails.root.join("spec/fixtures/files/sample.txt")), filename: "notes.txt", content_type: "text/plain")

      expect(salle).not_to be_valid
      expect(salle.errors[:images]).to be_present
    end

    it "rejects an oversized image" do
      salle = build(:salle)
      salle.images.attach(io: File.open(sample_path), filename: "room.png", content_type: "image/png")
      allow(salle.images.first.blob).to receive(:byte_size).and_return(HasPhotos::MAX_IMAGE_SIZE + 1)

      expect(salle).not_to be_valid
      expect(salle.errors[:images]).to be_present
    end

    it "rejects more than the maximum number of images" do
      salle = build(:salle)
      (HasPhotos::MAX_IMAGES + 1).times do |n|
        salle.images.attach(io: File.open(sample_path), filename: "room#{n}.png", content_type: "image/png")
      end

      expect(salle).not_to be_valid
      expect(salle.errors[:images]).to be_present
    end
  end
end
