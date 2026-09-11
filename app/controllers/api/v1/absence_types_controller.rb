module Api
  module V1
    # Leave / absence categories, managed from Settings. Owner-only (HR).
    class AbsenceTypesController < BaseController
      before_action :require_company!
      before_action :require_owner!
      before_action :set_type, only: [ :update, :destroy ]

      # GET /api/v1/absence_types
      def index
        types = current_company.absence_types.ordered
        render json: { absence_types: types.map { |t| AbsenceTypeSerializer.new(t).as_json } }
      end

      # POST /api/v1/absence_types
      def create
        type = current_company.absence_types.new(type_params)

        if type.save
          render json: { absence_type: AbsenceTypeSerializer.new(type).as_json }, status: :created
        else
          render_error(type)
        end
      end

      # PATCH /api/v1/absence_types/:id
      def update
        if @type.update(type_params)
          render json: { absence_type: AbsenceTypeSerializer.new(@type).as_json }
        else
          render_error(@type)
        end
      end

      # DELETE /api/v1/absence_types/:id — blocked while leave rows use it.
      def destroy
        if @type.destroy
          head :no_content
        else
          render json: { error: @type.errors.full_messages.first }, status: :unprocessable_entity
        end
      end

      private

      def set_type
        @type = current_company.absence_types.find(params[:id])
      end

      def type_params
        params.require(:absence_type).permit(:name, :abbreviation, :paid, :active, :position)
      end

      def render_error(record)
        render json: { error: record.errors.full_messages.first, errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
