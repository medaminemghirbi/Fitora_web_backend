class ClientSerializer
  def initialize(client, detailed: false)
    @client = client
    @detailed = detailed
  end

  def as_json(*)
    base = {
      id: client.id,
      first_name: client.first_name,
      last_name: client.last_name,
      full_name: client.full_name,
      email: client.email,
      phone: client.phone,
      active: client.active,
      login_enabled: client.login_enabled?,
      email_verified: client.email_verified?,
      joined_at: client.joined_at,
      current_contract: ContractSerializer.new(client.current_contract).as_json
    }

    return base unless detailed

    base.merge(
      date_of_birth: client.date_of_birth,
      gender: client.gender,
      address: client.address,
      emergency_contact_name: client.emergency_contact_name,
      emergency_contact_phone: client.emergency_contact_phone,
      notes: client.notes,
      outstanding_balance: client.outstanding_balance,
      attendance_rate: client.attendance_rate,
      last_visit_at: client.bookings.confirmed.joins(:session).maximum("sessions.starts_at")
    )
  end

  private

  attr_reader :client, :detailed
end
