class UserSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      locale: user.locale,
      email_verified: user.email_verified?,
      company_id: user.active_company_id || user.staff_member&.company_id,
      staff_role: user.staff_member&.role,
      companies: owner_companies
    }
  end

  private

  attr_reader :user

  # Only an owner ever has more than one — nil (not []) for anyone else,
  # so the frontend can tell "no switcher" apart from "switcher, empty".
  def owner_companies
    return nil unless user.owner?

    user.companies.order(:created_at).map { |c| CompanySummarySerializer.new(c, active: c.id == user.active_company_id).as_json }
  end
end
