module CheckIns
  class Create
    def self.call(booking:, marked_by:)
      Attendance::Mark.call(booking: booking, status: :present, marked_by: marked_by, checked_in_at: Time.current)
    end
  end
end
