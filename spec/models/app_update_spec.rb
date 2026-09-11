require "rails_helper"

RSpec.describe AppUpdate, type: :model do
  let(:sample_path) { Rails.root.join("spec/fixtures/files/sample.png") }

  it "requires a version and a title" do
    update = build(:app_update, version: nil, title: nil)

    expect(update).not_to be_valid
    expect(update.errors[:version]).to be_present
    expect(update.errors[:title]).to be_present
  end

  it "stamps published_at on create when not given" do
    update = create(:app_update)

    expect(update.published_at).to be_present
  end

  it "exposes the latest version via .current_version" do
    create(:app_update, version: "1.0.0", published_at: 2.days.ago)
    create(:app_update, version: "1.1.0", published_at: 1.day.ago)

    expect(described_class.current_version).to eq("1.1.0")
  end

  it "rejects a disallowed media content type" do
    update = build(:app_update)
    update.media.attach(io: File.open(sample_path), filename: "virus.exe", content_type: "application/x-msdownload", identify: false)

    expect(update).not_to be_valid
    expect(update.errors[:media]).to be_present
  end

  it "accepts an allowed image" do
    update = build(:app_update)
    update.media.attach(io: File.open(sample_path), filename: "screenshot.png", content_type: "image/png")

    expect(update).to be_valid
  end
end
