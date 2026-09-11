module Api
  module V1
    class AttendanceController < BaseController
      before_action :require_company!
      before_action :require_attendance_access!, only: [ :index, :create ]

      # GET /api/v1/attendance?session_id=
      def index
        session = accessible_sessions.find_by(id: params[:session_id])
        return render_not_found if session.nil?

        bookings = session.bookings.held.includes(:client, :attendance_record).order(:created_at)
        render json: { session: SessionSerializer.new(session).as_json, bookings: bookings.map { |b| AttendanceBookingSerializer.new(b).as_json } }
      end

      # POST /api/v1/attendance
      def create
        booking = Booking.joins(session: :location)
                          .where(locations: { company_id: current_company.id })
                          .find_by(id: params[:booking_id])
        return render json: { error: "Booking not found" }, status: :not_found if booking.nil?
        return render_forbidden unless can_mark?(booking.session)

        result = Attendance::Mark.call(booking: booking, status: params[:status], marked_by: current_user)

        if result.success?
          render json: { attendance: AttendanceBookingSerializer.new(booking.reload).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      # Coaches only ever touch their own sessions' attendance; everyone else
      # with the `sessions` capability sees the whole company.
      def accessible_sessions
        scope = Session.joins(:location).where(locations: { company_id: current_company.id })
        current_staff_member&.coach? ? scope.where(coach_id: current_staff_member.coach_id) : scope
      end

      def can_mark?(session)
        return true if current_user.owner?
        return false unless current_staff_member&.active? && current_staff_member.can?(:checkin)

        current_staff_member.coach? ? session.coach_id == current_staff_member.coach_id : true
      end

      # "checkin" (manager/receptionist/coach all have it) is enough to reach
      # this controller — the finer-grained coach-owns-this-session check
      # happens in can_mark?/accessible_sessions.
      def require_attendance_access!
        return if current_user.owner?
        return if current_staff_member&.active? && current_staff_member.can?(:checkin)

        render_forbidden
      end
    end
  end
end
