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

      existing_starts_ats = schedule.sessions.pluck(:starts_at).to_set

      each_occurrence_date do |date|
        starts_at = date.to_time(:utc).change(hour: schedule.start_time.hour, min: schedule.start_time.min)

        if existing_starts_ats.include?(starts_at)
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

    def each_occurrence_date
      (schedule.starts_on..schedule.generation_end_date).each do |date|
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
        location_id: schedule.location_id,
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
