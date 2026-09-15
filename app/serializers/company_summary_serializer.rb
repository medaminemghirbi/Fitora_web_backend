# The lightweight shape used everywhere a caller just needs to list/pick
# one of an owner's companies (the navbar switcher, the owner's own user
# payload) — CompanySerializer is the full, heavier shape for "the
# currently active company's own settings screen."
class CompanySummarySerializer
  def initialize(company, active: nil)
    @company = company
    @active = active
  end

  def as_json(*)
    return nil if company.nil?

    {
      id: company.id,
      name: company.name,
      logo_url: logo_url,
      currency: company.currency,
      active: active
    }
  end

  private

  attr_reader :company, :active

  def logo_url
    return nil unless company.logo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(company.logo, only_path: true)
  end
end
