class LeaveRequestSerializer
  def initialize(leave)
    @leave = leave
  end

  def as_json(*)
    {
      id: leave.id,
      staff_member_id: leave.staff_member_id,
      absence_type_id: leave.absence_type_id,
      absence_type: {
        id: leave.absence_type.id,
        name: leave.absence_type.name,
        abbreviation: leave.absence_type.abbreviation,
        paid: leave.absence_type.paid
      },
      starts_on: leave.starts_on,
      ends_on: leave.ends_on,
      days_count: leave.days_count.to_f,
      status: leave.status,
      reason: leave.reason,
      recorded_by: leave.recorded_by && { id: leave.recorded_by.id, full_name: leave.recorded_by.full_name },
      created_at: leave.created_at
    }
  end

  private

  attr_reader :leave
end
