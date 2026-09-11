require "rails_helper"

RSpec.describe Activity, type: :model do
  describe "session_format / capacity" do
    it "accepts a matching capacity for each format" do
      expect(build(:activity, session_format: :individual, capacity: 1)).to be_valid
      expect(build(:activity, session_format: :small_group, capacity: 2)).to be_valid
      expect(build(:activity, session_format: :small_group, capacity: 9)).to be_valid
      expect(build(:activity, session_format: :collective, capacity: 10)).to be_valid
      expect(build(:activity, session_format: :collective, capacity: 40)).to be_valid
    end

    it "rejects an individual activity with more than one seat" do
      activity = build(:activity, session_format: :individual, capacity: 3)

      expect(activity).not_to be_valid
      expect(activity.errors[:capacity].first).to match(/must be 1 for an individual/)
    end

    it "rejects a small-group activity outside 2–9" do
      expect(build(:activity, session_format: :small_group, capacity: 1)).not_to be_valid
      expect(build(:activity, session_format: :small_group, capacity: 10)).not_to be_valid
    end

    it "rejects a collective activity below 10" do
      activity = build(:activity, session_format: :collective, capacity: 8)

      expect(activity).not_to be_valid
      expect(activity.errors[:capacity].first).to match(/at least 10/)
    end
  end
end
