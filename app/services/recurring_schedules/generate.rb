module RecurringSchedules
  class Generate
    Result = Struct.new(:created_count, :skipped_count, :conflict_errors, keyword_init: true)

    def self.call(schedule:)
      new(schedule: schedule).call
    end

    def initialize(schedule:)
      @schedule = schedule
    end

    def call
      created = 0
      skipped = 0
      conflicts = []

      existing_starts_ats = schedule.sessions.pluck(:starts_at).to_set(&:to_i)

      each_occurrence_date do |date|
        # 18:00 is 18:00 at the gym. This used to build the time in UTC, so
        # every generated class landed an hour late in Tunis — while a
        # one-off session from the calendar, converted by the browser, was
        # right.
        starts_at = zone.local(date.year, date.month, date.day, schedule.start_time.hour, schedule.start_time.min)

        if existing_starts_ats.include?(starts_at.to_i)
          skipped += 1
          next
        end

        result = Sessions::Create.call(attributes: session_attributes(starts_at))

        if result.success?
          created += 1
        else
          conflicts << { starts_at: starts_at, error: result.error }
        end
      end

      Result.new(created_count: created, skipped_count: skipped, conflict_errors: conflicts)
    end

    private

    attr_reader :schedule

    def zone
      @zone ||= schedule.company.time_zone
    end

    def each_occurrence_date
      last = Time.use_zone(zone) { schedule.generation_end_date }
      (schedule.starts_on..last).each do |date|
        yield date if occurs_on?(date)
      end
    end

    def occurs_on?(date)
      case schedule.recurrence_type
      when "weekly" then schedule.weekdays.include?(date.wday)
      when "daily" then true
      when "monthly" then date.day == schedule.starts_on.day
      end
    end

    def session_attributes(starts_at)
      {
        activity_id: schedule.activity_id,
        company_id: schedule.company_id,
        coach_id: schedule.coach_id,
        recurring_schedule_id: schedule.id,
        starts_at: starts_at,
        ends_at: starts_at + schedule.activity.duration.minutes,
        capacity: schedule.activity.capacity,
        status: :scheduled
      }
    end
  end
end
