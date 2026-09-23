class ClientSerializer
  # `company` is the gym looking at this person. It is what scopes their
  # contracts, money and attendance to that gym, and where "active", "joined"
  # and the gym's private notes come from — those belong to the membership,
  # not to the person. Passing nil is the person's own, cross-gym view.
  # `last_visit_at` is passed in rather than computed here: on a list it is
  # one grouped query for the whole page (see
  # Api::V1::ClientsController#last_visits_for), and computing it per record
  # would make that impossible.
  def initialize(client, detailed: false, company: nil, last_visit_at: :unset)
    @client = client
    @detailed = detailed
    @company = company
    @membership = company && client.membership_for(company)
    @last_visit_at = last_visit_at
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

    # Only when the caller supplied it. A list sends it; anything that did
    # not ask gets no key at all rather than a misleading null.
    base[:last_visit_at] = @last_visit_at unless @last_visit_at == :unset

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
      last_visit_at: @last_visit_at == :unset ?
        client.bookings_for(company).confirmed.joins(:session).maximum("sessions.starts_at") :
        @last_visit_at
    )
  end

  private

  attr_reader :client, :detailed, :company, :membership
end
