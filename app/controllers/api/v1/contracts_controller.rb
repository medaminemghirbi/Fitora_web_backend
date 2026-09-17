module Api
  module V1
    class ContractsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:contracts) }
      before_action :set_contract, only: [ :show, :update, :renew, :cancel, :destroy, :receipt ]

      # GET /api/v1/contracts — the company's contracts (filterable by status
      # and/or contract_type_id)
      def index
        searched = searched_scope
        contracts = searched
        contracts = on_current_period(contracts, params[:status]) if params[:status].present?
        contracts = contracts.where(contract_type_id: params[:contract_type_id]) if params[:contract_type_id].present?

        render json: {
          contracts: paginate(contracts).map { |m| ContractSerializer.new(m).as_json },
          meta: pagination_meta(contracts),
          counts: status_counts(searched),
          plan_counts: plan_counts(searched),
          totals: portfolio_totals(searched)
        }
      end

      # The list's status filter, and its counts, both look at each contract's
      # CURRENT (latest) period only — not any period in its history.
      def on_current_period(scope, status)
        scope.joins(:contract_periods)
             .where(contract_periods: { status: status })
             .where(<<~SQL.squish)
               contract_periods.id = (
                 SELECT cp2.id FROM contract_periods cp2
                 WHERE cp2.contract_id = contracts.id
                 ORDER BY cp2.starts_at DESC, cp2.created_at DESC LIMIT 1
               )
             SQL
      end

      def searched_scope
        scope = current_company.contracts.includes(:contract_type, :client, :contract_periods).order(created_at: :desc)
        return scope if params[:q].blank?

        t = "%#{params[:q].strip}%"
        scope.joins(:client).joins(:contract_type)
             .where("clients.first_name ILIKE :t OR clients.last_name ILIKE :t OR contract_types.name ILIKE :t", t: t)
      end

      # GET /api/v1/contracts/:id
      def show
        render json: { contract: ContractSerializer.new(@contract).as_json }
      end

      # POST /api/v1/contracts — staff gives a client a contract
      def create
        client = current_company.clients.find_by(id: params[:client_id])
        return render json: { error: "Client not found" }, status: :not_found if client.nil?

        plan = current_company.contract_types.active.find_by(id: params[:contract_type_id])
        return render json: { error: "Contract plan not found" }, status: :not_found if plan.nil?

        activity = current_company.activities.find_by(id: params[:activity_id])
        return render json: { error: "Activity not found" }, status: :not_found if activity.nil?

        result = Contracts::Create.call(
          client: client, contract_type: plan, activity: activity, created_by: current_user,
          starts_on: params[:starts_on].present? ? Date.parse(params[:starts_on]) : Date.current,
          discount: params[:discount].presence || 0,
          collect_payment: params[:collect_payment], payment_method: params[:payment_method]
        )

        if result.success?
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "contract.created",
            auditable: result.contract, metadata: { client: client.full_name, plan: plan.name }
          )
          render json: {
            contract: ContractSerializer.new(result.contract).as_json,
            payment: PaymentSerializer.new(result.payment).as_json
          }, status: :created
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/contracts/:id — edit the current period (dates, discount)
      def update
        result = Contracts::UpdatePeriod.call(
          contract: @contract,
          starts_on: params[:starts_on], expires_on: params[:expires_on], discount: params[:discount]
        )

        if result.success?
          render json: { contract: ContractSerializer.new(result.contract).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # POST /api/v1/contracts/:id/renew
      def renew
        result = Contracts::Renew.call(contract: @contract, created_by: current_user)

        if result.success?
          render json: { contract: ContractSerializer.new(result.contract).as_json }, status: :created
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # POST /api/v1/contracts/:id/cancel
      def cancel
        result = Contracts::Cancel.call(contract: @contract)

        if result.success?
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "contract.cancelled",
            auditable: @contract, metadata: { client: @contract.client.full_name, plan: @contract.contract_type.name }
          )
          render json: { contract: ContractSerializer.new(@contract.reload).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/contracts/:id — only once cancelled, so this is
      # never how history disappears by accident: cancel (soft, reversible
      # by re-subscribing) is the everyday action; destroy is a deliberate
      # second step for actually clearing clutter out of a client's history.
      def destroy
        unless @contract.cancelled?
          return render json: { error: "Only cancelled contracts can be deleted" }, status: :unprocessable_content
        end

        metadata = { client: @contract.client.full_name, plan: @contract.contract_type.name }
        @contract.destroy!
        AuditLogs::Record.call(company: current_company, user: current_user, action: "contract.deleted", auditable: @contract, metadata: metadata)

        head :no_content
      end

      # The list's status filter, and its counts, both look at each contract's
      # CURRENT (latest) period only — not any period in its history.
      def on_current_period(scope, status)
        scope.joins(:contract_periods)
             .where(contract_periods: { status: status })
             .where(<<~SQL.squish)
               contract_periods.id = (
                 SELECT cp2.id FROM contract_periods cp2
                 WHERE cp2.contract_id = contracts.id
                 ORDER BY cp2.starts_at DESC, cp2.created_at DESC LIMIT 1
               )
             SQL
      end

      def searched_scope
        scope = current_company.contracts.includes(:contract_type, :client, :contract_periods).order(created_at: :desc)
        return scope if params[:q].blank?

        t = "%#{params[:q].strip}%"
        scope.joins(:client).joins(:contract_type)
             .where("clients.first_name ILIKE :t OR clients.last_name ILIKE :t OR contract_types.name ILIKE :t", t: t)
      end

      # GET /api/v1/contracts/:id/receipt — available to anyone who can
      # already see this contract (require_capability!(:contracts)).
      def receipt
        pdf_data = Receipts::ContractPdf.call(contract: @contract)

        send_data pdf_data,
                   filename: "recu-#{@contract.client.full_name.parameterize}-#{@contract.id.split('-').first}.pdf",
                   type: "application/pdf",
                   disposition: "attachment"
      end

      private

      # What the filter rail and the stats strip read. Everything here follows
      # the search term but ignores the status/plan already picked, so the
      # numbers stay comparable while the operator clicks around.
      def status_counts(searched)
        ContractPeriod.statuses.keys.index_with { |status| on_current_period(searched, status).distinct.count }
                      .merge("all" => searched.distinct.count, "unpaid" => unpaid_scope(searched).distinct.count)
      end

      def plan_counts(searched)
        searched.reorder(nil).group(:contract_type_id).distinct.count
      end

      def unpaid_scope(searched)
        on_current_period(searched, :active).where(contract_periods: { payment_status: :unpaid })
      end

      # The portfolio is what the ACTIVE contracts were sold for — the frozen
      # period prices, never today's catalogue.
      def portfolio_totals(searched)
        active = on_current_period(searched, :active)
        value = active.sum("contract_periods.final_price")
        count = active.distinct.count
        {
          portfolio_value: value.to_f,
          average_basket: count.positive? ? (value.to_f / count).round(2) : 0.0,
          unpaid_value: unpaid_scope(searched).sum("contract_periods.final_price").to_f,
          expiring_soon: on_current_period(searched, :active)
            .where(contract_periods: { expires_at: Time.current..30.days.from_now }).distinct.count
        }
      end

      def set_contract
        @contract = current_company.contracts.find(params[:id])
      end
    end
  end
end
