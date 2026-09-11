module Payroll
  # Builds the monthly "pré-fiche de paie" for a company: for every employee
  # with an employment contract, a day-by-day work/absence grid for the
  # month, absence totals by type, and a gross-salary estimate. It is a
  # *pre*-sheet — the accountant finalises CNSS / IRPP / net from it.
  #
  # Working days come from Company#working_days (Date#wday integers; default
  # Monday–Friday, a Saturday-opening gym adds 6). Public holidays are not
  # modelled yet. "Paid" absence types (AbsenceType#paid) are treated as
  # salaried; non-paid ones feed a pro-rata deduction on the estimate.
  class MonthlySheet
    FR_MONTHS = %w[janvier février mars avril mai juin juillet août septembre octobre novembre décembre].freeze

    Day = Struct.new(:date, :code, :absence_abbr, :absence_name, keyword_init: true)

    def self.call(company:, year:, month:)
      new(company: company, year: year, month: month).call
    end

    def initialize(company:, year:, month:)
      @company = company
      @first = Date.new(year, month, 1)
      @last = @first.end_of_month
      @dates = (@first..@last).to_a
    end

    def call
      {
        month: @first.strftime("%Y-%m"),
        month_label: "#{FR_MONTHS[@first.month - 1].capitalize} #{@first.year}",
        working_days: @dates.count { |d| working_day?(d) },
        currency: @company.currency,
        employees: employee_sheets
      }
    end

    private

    def working_day?(date)
      @company.working_day?(date)
    end

    def employee_sheets
      staff = @company.staff_members
                      .includes(:user, work_contracts: :work_contract_type, leave_requests: :absence_type)
      # Coaches with no app login are employed directly (WorkContract#coach);
      # they have no leave_requests, so their grid is just worked/off.
      coaches = @company.coaches.joins(:work_contracts).distinct
                        .includes(work_contracts: :work_contract_type)

      (staff.to_a + coaches.to_a)
        .filter_map { |employee| employee_sheet(employee) }
        .sort_by { |e| e[:name] }
    end

    # Returns nil for anyone not on the payroll that month (no contract that
    # overlaps it).
    def employee_sheet(employee)
      contract = contract_for_month(employee)
      return nil if contract.nil?
      contract_start = contract.starts_on
      contract_end = contract.terminated_on || contract.ends_on

      is_coach = employee.is_a?(Coach)
      leaves = is_coach ? [] : employee.leave_requests.select { |lr| lr.status_approved? && overlaps_month?(lr) }

      days = @dates.map do |date|
        if !working_day?(date)
          Day.new(date: date, code: "off")
        elsif contract_start && date < contract_start
          Day.new(date: date, code: "na")
        elsif contract_end && date > contract_end
          Day.new(date: date, code: "na")
        elsif (leave = leaves.find { |lr| date.between?(lr.starts_on, lr.ends_on) })
          Day.new(date: date, code: leave.absence_type.paid ? "leave_paid" : "leave_unpaid",
                  absence_abbr: leave.absence_type.abbreviation, absence_name: leave.absence_type.name)
        else
          Day.new(date: date, code: "worked")
        end
      end

      working_days = days.count { |d| %w[worked leave_paid leave_unpaid].include?(d.code) }
      worked_days = days.count { |d| d.code == "worked" }
      paid_absence_days = days.count { |d| d.code == "leave_paid" }
      unpaid_absence_days = days.count { |d| d.code == "leave_unpaid" }

      absences = leaves.group_by(&:absence_type).map do |absence_type, type_leaves|
        {
          absence_type: absence_type.name,
          abbreviation: absence_type.abbreviation,
          paid: absence_type.paid,
          days: days.count { |d| d.absence_abbr == absence_type.abbreviation },
          recorded_days: type_leaves.sum { |lr| lr.days_count.to_f }
        }
      end

      total_gross = contract.total_monthly_gross
      estimated_gross =
        if working_days.zero?
          0.0
        else
          (total_gross * (working_days - unpaid_absence_days) / working_days).round(3)
        end

      {
        staff_member_id: is_coach ? nil : employee.id,
        coach_id: is_coach ? employee.id : nil,
        name: is_coach ? employee.full_name : employee.user.full_name,
        role: is_coach ? "coach" : employee.role,
        job_title: contract.job_title,
        contract: {
          type: contract.work_contract_type.abbreviation,
          type_name: contract.work_contract_type.name,
          reference: contract.reference,
          cnss_number: contract.cnss_number,
          starts_on: contract.starts_on,
          ends_on: contract_end,
          status: contract.status
        },
        gross_monthly_salary: contract.gross_monthly_salary.to_f,
        allowances: contract.allowances,
        allowances_total: contract.allowances_total,
        total_monthly_gross: total_gross,
        currency: contract.currency,
        working_days: working_days,
        worked_days: worked_days,
        absence_days: paid_absence_days + unpaid_absence_days,
        paid_absence_days: paid_absence_days,
        unpaid_absence_days: unpaid_absence_days,
        estimated_gross: estimated_gross,
        absences: absences,
        days: days.map { |d| { date: d.date, weekday: d.date.wday, code: d.code, abbr: d.absence_abbr } }
      }
    end

    # The contract that covers the month (most working-day overlap wins,
    # active status breaks ties). nil when the employee had no contract that
    # month.
    def contract_for_month(employee)
      far_future = Date.new(9999, 12, 31)
      employee.work_contracts
                  .select { |c| c.starts_on <= @last && (c.terminated_on || c.ends_on || far_future) >= @first }
                  .max_by { |c| [ overlap_days(c), c.active? ? 1 : 0 ] }
    end

    def overlap_days(contract)
      c_end = contract.terminated_on || contract.ends_on || @last
      ([ contract.starts_on, @first ].max..[ c_end, @last ].min).count { |d| working_day?(d) }
    end

    def overlaps_month?(leave)
      leave.starts_on <= @last && leave.ends_on >= @first
    end
  end
end
