module Api
  module V1
    # Leave / absences an owner records in an employee's file. Owner-only.
    class LeaveRequestsController < BaseController
      before_action :require_company!
      before_action :require_owner!
      before_action :set_leave, only: [ :update, :destroy ]

      # GET /api/v1/leave_requests?staff_member_id=…&year=…
      def index
        leaves = current_company.leave_requests.includes(:recorded_by, :absence_type).recent_first
        leaves = leaves.where(staff_member_id: params[:staff_member_id]) if params[:staff_member_id].present?
        leaves = leaves.in_year(params[:year]) if params[:year].present?

        render json: { leave_requests: leaves.map { |l| LeaveRequestSerializer.new(l).as_json } }
      end

      # POST /api/v1/leave_requests
      def create
        leave = current_company.leave_requests.new(leave_params.except(:staff_member_id))
        leave.recorded_by = current_user
        leave.staff_member = current_company.staff_members.find(leave_params[:staff_member_id])

        if leave.save
          render json: { leave_request: LeaveRequestSerializer.new(leave).as_json }, status: :created
        else
          render_error(leave)
        end
      end

      # PATCH /api/v1/leave_requests/:id
      def update
        if @leave.update(leave_params.except(:staff_member_id))
          render json: { leave_request: LeaveRequestSerializer.new(@leave).as_json }
        else
          render_error(@leave)
        end
      end

      # DELETE /api/v1/leave_requests/:id
      def destroy
        @leave.destroy
        head :no_content
      end

      private

      def set_leave
        @leave = current_company.leave_requests.find(params[:id])
      end

      def leave_params
        params.require(:leave_request).permit(:staff_member_id, :absence_type_id, :starts_on, :ends_on, :days_count, :status, :reason)
      end

      def render_error(record)
        render json: { error: record.errors.full_messages.first, errors: record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
