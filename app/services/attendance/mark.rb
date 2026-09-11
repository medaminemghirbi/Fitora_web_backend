module Attendance
  class Mark
    Result = Struct.new(:success?, :attendance_record, :error, keyword_init: true)

    def self.call(booking:, status:, marked_by:, checked_in_at: nil, checked_out_at: nil)
      new(booking: booking, status: status, marked_by: marked_by, checked_in_at: checked_in_at, checked_out_at: checked_out_at).call
    end

    def initialize(booking:, status:, marked_by:, checked_in_at: nil, checked_out_at: nil)
      @booking = booking
      @status = status
      @marked_by = marked_by
      @checked_in_at = checked_in_at
      @checked_out_at = checked_out_at
    end

    def call
      record = nil

      ActiveRecord::Base.transaction do
        # find_or_initialize keeps this idempotent — marking the same
        # booking's attendance twice updates the one record instead of
        # erroring on the unique booking_id index.
        record = AttendanceRecord.lock.find_or_initialize_by(booking: booking)
        record.status = status
        record.marked_by = marked_by
        record.checked_in_at = checked_in_at if checked_in_at
        record.checked_out_at = checked_out_at if checked_out_at
        record.save!
      end

      Result.new(success?: true, attendance_record: record, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, attendance_record: nil, error: e.record.errors.full_messages.first)
    rescue ActiveRecord::RecordNotUnique
      # Two concurrent first-time marks for the same booking — the loser
      # just updates the row the winner created instead of erroring.
      call
    end

    private

    attr_reader :booking, :status, :marked_by, :checked_in_at, :checked_out_at
  end
end
