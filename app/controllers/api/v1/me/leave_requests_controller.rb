module Api
  module V1
    module Me
      # A staff member's OWN leave requests — self-service counterpart to
      # the owner-facing LeaveRequestsController (which records leave FOR an
      # employee, and can set any status directly). Every request created
      # here starts pending — only the owner approves/rejects it, still via
      # LeaveRequestsController#update.
      class LeaveRequestsController < BaseController
        before_action :require_staff_member!

        # GET /api/v1/me/leave_requests — the coach app's "Mes congés" screen:
        # history + the CP balance + the absence types to pick from when
        # filing a new one.
        def index
          leaves = current_staff_member.leave_requests.includes(:absence_type).recent_first

          render json: {
            leave_requests: leaves.map { |l| LeaveRequestSerializer.new(l).as_json },
            absence_types: current_staff_member.company.absence_types.active.ordered.map { |t| AbsenceTypeSerializer.new(t).as_json },
            balance: current_staff_member.paid_leave_balance
          }
        end

        # POST /api/v1/me/leave_requests
        def create
          leave = current_staff_member.leave_requests.new(leave_params)
          leave.company = current_staff_member.company
          leave.status = :pending
          leave.recorded_by = current_user

          if leave.save
            render json: { leave_request: LeaveRequestSerializer.new(leave).as_json }, status: :created
          else
            render json: { error: leave.errors.full_messages.first, errors: leave.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def require_staff_member!
          render_forbidden if current_staff_member.nil?
        end

        def leave_params
          params.require(:leave_request).permit(:absence_type_id, :starts_on, :ends_on, :days_count, :reason)
        end
      end
    end
  end
end
