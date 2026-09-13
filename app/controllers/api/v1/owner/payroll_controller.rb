module Api
  module V1
    module Owner
      # Monthly pré-fiche de paie — the work/absence grid and gross-salary
      # estimate per employee, plus a PDF export. Owner-only (HR).
      class PayrollController < BaseController
        before_action :require_owner!
        before_action :require_company!
        before_action :set_month

        # GET /api/v1/owner/payroll?month=2026-08
        def index
          render json: Payroll::MonthlySheet.call(company: current_company, year: @year, month: @month)
        end

        # GET /api/v1/owner/payroll/export?month=2026-08[&staff_member_id=…]
        def export
          sheet = Payroll::MonthlySheet.call(company: current_company, year: @year, month: @month)
          employees = sheet[:employees]

          if params[:staff_member_id].present?
            employees = employees.select { |e| e[:staff_member_id] == params[:staff_member_id] }
            return render(json: { error: "not_found" }, status: :not_found) if employees.empty?
          elsif params[:coach_id].present?
            employees = employees.select { |e| e[:coach_id] == params[:coach_id] }
            return render(json: { error: "not_found" }, status: :not_found) if employees.empty?
          end

          pdf = Payroll::SheetPdf.call(company: current_company, sheet: sheet, employees: employees)
          suffix = params[:staff_member_id].present? ? employees.first[:name].parameterize : "equipe"

          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "payroll.exported",
            auditable: current_company, metadata: { month: sheet[:month], scope: suffix }
          )

          send_data pdf,
                    filename: "pre-fiche-paie-#{sheet[:month]}-#{suffix}.pdf",
                    type: "application/pdf",
                    disposition: "attachment"
        end

        private

        def set_month
          @year, @month = params[:month].to_s.split("-").map { |p| Integer(p, 10) }
          raise ArgumentError unless @month&.between?(1, 12) && @year&.between?(2000, 2100)
        rescue ArgumentError, TypeError
          today = Date.current
          @year = today.year
          @month = today.month
        end
      end
    end
  end
end
