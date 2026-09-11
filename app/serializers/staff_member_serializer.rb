class StaffMemberSerializer
  def initialize(staff_member)
    @staff_member = staff_member
  end

  def as_json(*)
    {
      id: staff_member.id,
      role: staff_member.role,
      role_key: staff_member.role_key,
      role_name: staff_member.assigned_role&.name,
      permissions: staff_member.permission_keys,
      active: staff_member.active,
      birthdate: staff_member.birthdate,
      user: {
        id: staff_member.user.id,
        full_name: staff_member.user.full_name,
        email: staff_member.user.email,
        phone: staff_member.user.phone
      },
      coach_id: staff_member.coach_id,
      location_ids: staff_member.location_ids
    }
  end

  private

  attr_reader :staff_member
end
