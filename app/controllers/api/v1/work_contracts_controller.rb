module Api
  module V1
    # An employee's employment contracts. Owner-only (HR). Always filtered
    # through the company, and scoped to one staff member on index via
    # ?staff_member_id=.
    class WorkContractsController < BaseController
      before_action :require_company!
      before_action :require_owner!
      before_action :set_contract, only: [ :show, :update, :destroy ]

      # GET /api/v1/work_contracts?staff_member_id=… or ?coach_id=…
      def index
        contracts = current_company.work_contracts
                                   .includes(:coach, :work_contract_type, staff_member: :user)
                                   .active_first
        contracts = contracts.where(staff_member_id: params[:staff_member_id]) if params[:staff_member_id].present?
        contracts = contracts.where(coach_id: params[:coach_id]) if params[:coach_id].present?

        render json: { work_contracts: contracts.map { |c| WorkContractSerializer.new(c).as_json } }
      end

      # GET /api/v1/work_contracts/:id
      def show
        render json: { work_contract: WorkContractSerializer.new(@contract).as_json }
      end

      # POST /api/v1/work_contracts
      def create
        contract = current_company.work_contracts.new(contract_params)
        contract.currency = current_company.currency if contract.currency.blank?

        if contract.save
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "work_contract.created",
            auditable: contract,
            metadata: { staff_member_id: contract.staff_member_id, coach_id: contract.coach_id }
          )
          render json: { work_contract: WorkContractSerializer.new(contract).as_json }, status: :created
        else
          render_error(contract)
        end
      end

      # PATCH /api/v1/work_contracts/:id
      def update
        if @contract.update(contract_params)
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "work_contract.updated",
            auditable: @contract,
            metadata: { staff_member_id: @contract.staff_member_id, coach_id: @contract.coach_id }
          )
          render json: { work_contract: WorkContractSerializer.new(@contract).as_json }
        else
          render_error(@contract)
        end
      end

      # DELETE /api/v1/work_contracts/:id
      def destroy
        metadata = { staff_member_id: @contract.staff_member_id, coach_id: @contract.coach_id }
        @contract.destroy
        AuditLogs::Record.call(
          company: current_company, user: current_user, action: "work_contract.deleted",
          auditable: @contract, metadata: metadata
        )
        head :no_content
      end

      private

      def set_contract
        @contract = current_company.work_contracts.find(params[:id])
      end

      def contract_params
        params.require(:work_contract).permit(
          :staff_member_id, :coach_id, :work_contract_type_id, :reference, :job_title,
          :starts_on, :ends_on, :trial_period_end, :weekly_hours,
          :gross_monthly_salary, :hourly_rate, :currency, :payment_method,
          :bank_name, :bank_iban, :cnss_number, :cnss_affiliated_on,
          :paid_leave_days_per_year, :notice_period_days, :terminated_on,
          :termination_reason, :status, :notes,
          allowances: [ :label, :amount ]
        )
      end

      def render_error(record)
        render json: { error: record.errors.full_messages.first, errors: record.errors.full_messages }, status: :unprocessable_content
      end
    end
  end
end
