class ActivityPolicy < CompanyScopedPolicy
  private

  def record_company_id
    record.location.company_id
  end
end
