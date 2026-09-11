class RoleSerializer
  def initialize(role)
    @role = role
  end

  def as_json(*)
    {
      id: role.id,
      key: role.key,
      name: role.name,
      permissions: role.permissions,
      builtin: role.builtin,
      deletable: role.deletable?,
      staff_count: role.staff_members.size
    }
  end

  private

  attr_reader :role
end
