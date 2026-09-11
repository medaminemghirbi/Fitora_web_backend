module Api
  module V1
    # Employment-contract categories (CDI, CDD, SIVP, …). HR administration is
    # owner-only, same as staff management.
    class WorkContractTypesController < BaseController
      before_action :require_company!
      before_action :require_owner!
      before_action :set_type, only: [ :update, :destroy ]

      # GET /api/v1/work_contract_types
      def index
        types = current_company.work_contract_types.ordered
        render json: { work_contract_types: types.map { |t| WorkContractTypeSerializer.new(t).as_json } }
      end

      # POST /api/v1/work_contract_types
      def create
        type = current_company.work_contract_types.new(type_params)

        if type.save
          render json: { work_contract_type: WorkContractTypeSerializer.new(type).as_json }, status: :created
        else
          render_error(type)
        end
      end

      # PATCH /api/v1/work_contract_types/:id
      def update
        if @type.update(type_params)
          render json: { work_contract_type: WorkContractTypeSerializer.new(@type).as_json }
        else
          render_error(@type)
        end
      end

      # DELETE /api/v1/work_contract_types/:id — blocked while contracts use it
      # (restrict_with_error).
      def destroy
        if @type.destroy
          head :no_content
        else
          render json: { error: @type.errors.full_messages.first }, status: :unprocessable_entity
        end
      end

      private

      def set_type
        @type = current_company.work_contract_types.find(params[:id])
      end

      def type_params
        params.require(:work_contract_type).permit(:name, :abbreviation, :fixed_term, :active, :position)
      end

      def render_error(record)
        render json: { error: record.errors.full_messages.first, errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
