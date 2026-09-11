module Api
  module V1
    class ContractTypesController < BaseController
      before_action :require_company!
      # Reading the plan list is part of signing a member up (:contracts);
      # editing the catalogue — prices, session counts — is configuration.
      before_action -> { require_capability!(:contracts) }, only: [ :index, :show ]
      before_action -> { require_capability!(:contract_types) }, only: [ :create, :update ]
      before_action :set_plan, only: [ :show, :update ]

      # GET /api/v1/contract_types
      def index
        plans = current_company.contract_types.order(:price)
        render json: { plans: plans.map { |p| ContractTypeSerializer.new(p).as_json } }
      end

      # GET /api/v1/contract_types/:id
      def show
        render json: { plan: ContractTypeSerializer.new(@plan).as_json }
      end

      # POST /api/v1/contract_types
      def create
        plan = current_company.contract_types.new(plan_params)

        if plan.save
          sync_associations(plan)
          render json: { plan: ContractTypeSerializer.new(plan).as_json }, status: :created
        else
          render json: { error: plan.errors.full_messages.first, errors: plan.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/contract_types/:id
      def update
        if @plan.update(plan_params)
          sync_associations(@plan)
          render json: { plan: ContractTypeSerializer.new(@plan).as_json }
        else
          render json: { error: @plan.errors.full_messages.first, errors: @plan.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_plan
        @plan = current_company.contract_types.find(params[:id])
      end

      def sync_associations(plan)
        return unless params[:activity_ids]

        plan.activity_ids = Array(params[:activity_ids]) & current_company.locations.joins(:activities).pluck("activities.id")
      end

      def plan_params
        params.require(:contract_type).permit(
          :name, :description, :price, :currency, :billing_period, :session_count,
          :unlimited_bookings, :booking_limit, :priority_booking, :active, :color
        )
      end
    end
  end
end
