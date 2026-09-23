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
        # Was ordered by the flat price, which no longer exists — a plan now
        # has one price per activity. Shortest commitment first, then name.
        plans = current_company.contract_types.order(:billing_period, :name)
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

      # The plan's pricing grid: one { activity_id, price } per activity this
      # plan is sold for. Activities not listed are dropped — the plan simply
      # isn't offered for them. Ids from another company are ignored, same
      # guard the old activity_ids sync used.
      def sync_associations(plan)
        return unless params[:activity_prices]

        own_activity_ids = current_company.activities.ids
        rows = Array(params[:activity_prices]).filter_map do |row|
          activity_id = row[:activity_id].presence
          next unless own_activity_ids.include?(activity_id)

          { activity_id: activity_id, price: row[:price].to_f }
        end

        plan.contract_type_activities.where.not(activity_id: rows.map { |r| r[:activity_id] }).destroy_all
        rows.each do |row|
          plan.contract_type_activities.find_or_initialize_by(activity_id: row[:activity_id]).update!(price: row[:price])
        end
      end

      def plan_params
        params.require(:contract_type).permit(
          :name, :description, :billing_period, :session_count,
          :unlimited_bookings, :booking_limit, :priority_booking, :active, :color
        )
      end
    end
  end
end
