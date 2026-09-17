class LeadSerializer
  def initialize(lead)
    @lead = lead
  end

  def as_json(*)
    {
      id: lead.id,
      kind: lead.kind,
      status: lead.status,
      contact_name: lead.contact_name,
      gym_name: lead.gym_name,
      email: lead.email,
      phone: lead.phone,
      city: lead.city,
      locale: lead.locale,
      message: lead.message,
      internal_notes: lead.internal_notes,
      handled_at: lead.handled_at,
      handled_by: lead.handled_by&.full_name,
      company_id: lead.company_id,
      created_at: lead.created_at
    }
  end

  private

  attr_reader :lead
end
