module RecurringSchedules
  # Ending a weekly class. No new sessions are generated, and the ones
  # already on the calendar ahead of today are taken off — except any a
  # member has booked or queued for, which stay for the gym to handle one by
  # one rather than being cancelled under someone's feet.
  class Stop
    Result = ServiceResult.define(:schedule, :cancelled_sessions, :kept_sessions)

    def self.call(schedule:) = new(schedule: schedule).call

    def initialize(schedule:)
      @schedule = schedule
    end

    def call
      cancelled = 0
      kept = 0

      ActiveRecord::Base.transaction do
        schedule.update!(active: false)

        schedule.sessions.scheduled.where(starts_at: Time.current..).find_each do |session|
          if session.bookings.where(status: %i[confirmed waitlisted]).exists?
            kept += 1
          else
            Sessions::Cancel.call(session: session)
            cancelled += 1
          end
        end
      end

      Result.ok(schedule: schedule, cancelled_sessions: cancelled, kept_sessions: kept)
    end

    private

    attr_reader :schedule
  end
end
