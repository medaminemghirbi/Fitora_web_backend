class ClientSerializer
  # `company` is the gym looking at this person. It is what scopes their
  # contracts, money and attendance to that gym, and where "active", "joined"
  # and the gym's private notes come from — those belong to the membership,
  # not to the person. Passing nil is the person's own, cross-gym view.
  def initialize(client, detailed: false, company: nil)
    @client = client
    @detailed = detailed
    @company = company
    @membership = company && client.membership_for(company)
  end

  def as_json(*)
    base = {
      id: client.id,
      first_name: client.first_name,
      last_name: client.last_name,
      full_name: client.full_name,
      login_enabled: client.login_enabled?,
      email: client.email,
      phone: client.phone,
      active: membership ? membership.active : client.active,
      joined_at: membership&.joined_at,
      current_contract: ContractSerializer.new(client.current_contract(company)).as_json
    }

    return base unless detailed

    base.merge(
      date_of_birth: client.date_of_birth,
      gender: client.gender,
      address: client.address,
      emergency_contact_name: client.emergency_contact_name,
      emergency_contact_phone: client.emergency_contact_phone,
      notes: membership&.notes,
      outstanding_balance: client.outstanding_balance(company),
      attendance_rate: client.attendance_rate(company),
      last_visit_at: client.bookings_for(company).confirmed.joins(:session).maximum("sessions.starts_at")
    )
  end

  private

  attr_reader :client, :detailed, :company, :membership
end
