require "rails_helper"

RSpec.describe Space do
  let(:company) { create(:company) }

  describe "validations" do
    it "requires a name" do
      expect(build(:space, company: company, name: nil)).not_to be_valid
    end

    it "rejects a second room with the same name in the same gym" do
      create(:space, company: company, name: "Studio A")

      expect(build(:space, company: company, name: "Studio A")).not_to be_valid
      expect(build(:space, company: company, name: "studio a")).not_to be_valid
    end

    it "lets another gym use the same room name" do
      create(:space, company: company, name: "Studio A")

      expect(build(:space, company: create(:company), name: "Studio A")).to be_valid
    end

    it "rejects a capacity of zero or less but allows none at all" do
      expect(build(:space, company: company, capacity: 0)).not_to be_valid
      expect(build(:space, company: company, capacity: -2)).not_to be_valid
      expect(build(:space, company: company, capacity: nil)).to be_valid
    end
  end

  describe ".available_for" do
    let(:activity) { create(:activity, company: company) }
    let!(:studio) { create(:space, company: company) }
    let!(:ring) { create(:space, company: company) }

    it "offers every room when the activity names none — the common case" do
      expect(described_class.available_for(activity)).to contain_exactly(studio, ring)
    end

    it "offers only the named rooms once the activity restricts itself" do
      create(:activity_space, activity: activity, space: ring)

      expect(described_class.available_for(activity)).to contain_exactly(ring)
    end

    it "leaves out a room that has been deactivated" do
      studio.update!(active: false)

      expect(described_class.available_for(activity)).to contain_exactly(ring)
    end
  end

  describe "#deletable?" do
    let(:space) { create(:space, company: company) }

    it "is deletable when nothing upcoming is scheduled in it" do
      expect(space).to be_deletable
    end

    it "is not deletable while a session is still scheduled in it" do
      create(:session, company: company, activity: create(:activity, company: company), space: space)

      expect(space.reload).not_to be_deletable
    end

    it "is deletable again once that session is only history" do
      create(:session, company: company, activity: create(:activity, company: company),
                       space: space, starts_at: 3.days.ago, ends_at: 3.days.ago + 1.hour)

      expect(space.reload).to be_deletable
    end
  end

  describe "deleting a room" do
    it "keeps the sessions that happened in it, unassigned" do
      space = create(:space, company: company)
      session = create(:session, company: company, activity: create(:activity, company: company),
                                 space: space, starts_at: 3.days.ago, ends_at: 3.days.ago + 1.hour)

      space.destroy!

      expect(session.reload.space_id).to be_nil
      expect(Session.exists?(session.id)).to be(true)
    end
  end
end
