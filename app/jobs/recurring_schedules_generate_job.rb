# Keeps every active recurring schedule's 90-day generation window topped up.
# Idempotent — RecurringSchedules::Generate skips any date that already has a
# session, so running this daily (or twice by accident) never duplicates
# sessions. Uses the default ActiveJob :async adapter, same documented
# limitation as V1's session-reminder job (non-persistent across restarts;
# swap in a persistent adapter before relying on this in production).
class RecurringSchedulesGenerateJob < ApplicationJob
  queue_as :default

  def perform
    RecurringSchedule.active.where("ends_on >= ?", Date.current).find_each do |schedule|
      RecurringSchedules::Generate.call(schedule: schedule)
    end
  end
end
