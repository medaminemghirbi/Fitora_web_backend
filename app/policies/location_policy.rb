class LocationPolicy < CompanyScopedPolicy
  private

  def record_company_id
    record.company_id
  end
end
