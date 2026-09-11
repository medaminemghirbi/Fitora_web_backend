require "rails_helper"

RSpec.describe "Api::V1::RecurringSchedules", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }
  let!(:location) { create(:location, company: company) }
  let!(:activity) { create(:activity, location: location) }

  describe "GET /api/v1/recurring_schedules" do
    it "never exposes another company's recurring schedules" do
      create(:recurring_schedule, activity: activity, location: location, company: company)
      other_schedule = create(:recurring_schedule)

      get "/api/v1/recurring_schedules", headers: auth_headers(owner)

      ids = response.parsed_body["recurring_schedules"].map { |s| s["id"] }
      expect(ids).not_to include(other_schedule.id)
    end

    it "forbids a coach from listing recurring schedules" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/recurring_schedules", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/recurring_schedules" do
    it "rejects an activity_id belonging to another company" do
      other_activity = create(:activity)

      post "/api/v1/recurring_schedules",
           params: { recurring_schedule: { activity_id: other_activity.id, weekdays: [ 1 ], start_time: "18:00", recurrence_type: "weekly", starts_on: Date.current, ends_on: 30.days.from_now.to_date } },
           headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/recurring_schedules/:id" do
    it "rejects updates to another company's recurring schedule" do
      other_schedule = create(:recurring_schedule)

      patch "/api/v1/recurring_schedules/#{other_schedule.id}", params: { recurring_schedule: { active: false } }, headers: auth_headers(owner)

      expect(response).to have_http_status(:not_found)
    end
  end
end
