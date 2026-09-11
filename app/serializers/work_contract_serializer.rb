class WorkContractSerializer
  def initialize(contract)
    @contract = contract
  end

  def as_json(*)
    {
      id: contract.id,
      staff_member_id: contract.staff_member_id,
      staff_member: staff_member_json,
      coach_id: contract.coach_id,
      coach: coach_json,
      employee: {
        kind: contract.staff_member_id ? "staff" : "coach",
        id: contract.staff_member_id || contract.coach_id,
        full_name: contract.employee_name
      },
      work_contract_type_id: contract.work_contract_type_id,
      work_contract_type: {
        id: contract.work_contract_type.id,
        name: contract.work_contract_type.name,
        abbreviation: contract.work_contract_type.abbreviation,
        fixed_term: contract.work_contract_type.fixed_term
      },
      reference: contract.reference,
      job_title: contract.job_title,
      starts_on: contract.starts_on,
      ends_on: contract.ends_on,
      trial_period_end: contract.trial_period_end,
      weekly_hours: contract.weekly_hours&.to_f,
      gross_monthly_salary: contract.gross_monthly_salary.to_f,
      hourly_rate: contract.hourly_rate&.to_f,
      currency: contract.currency,
      payment_method: contract.payment_method,
      bank_name: contract.bank_name,
      bank_iban: contract.bank_iban,
      cnss_number: contract.cnss_number,
      cnss_affiliated_on: contract.cnss_affiliated_on,
      allowances: contract.allowances,
      allowances_total: contract.allowances_total,
      total_monthly_gross: contract.total_monthly_gross,
      paid_leave_days_per_year: contract.paid_leave_days_per_year.to_f,
      notice_period_days: contract.notice_period_days,
      terminated_on: contract.terminated_on,
      termination_reason: contract.termination_reason,
      status: contract.status,
      notes: contract.notes,
      created_at: contract.created_at
    }
  end

  private

  attr_reader :contract

  def staff_member_json
    return nil if contract.staff_member.blank?

    {
      id: contract.staff_member.id,
      full_name: contract.staff_member.user.full_name,
      role: contract.staff_member.role
    }
  end

  def coach_json
    return nil if contract.coach.blank?

    { id: contract.coach.id, full_name: contract.coach.full_name }
  end
end
