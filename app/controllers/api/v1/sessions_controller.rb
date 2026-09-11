module Api
  module V1
    class SessionsController < BaseController
      before_action :require_company!
      before_action :require_staff!, only: [ :index, :show ]
      before_action :require_session_management!, only: [ :create, :update, :cancel ]
      before_action :set_session, only: [ :show, :update, :cancel ]

      # GET /api/v1/sessions?location_id=&activity_id=&coach_id=&date=&status=
      # GET /api/v1/sessions?from=&to=&... — range query, used by the calendar
      def index
        scope = base_scope
        scope = scope.where(location_id: params[:location_id]) if params[:location_id].present?
        scope = scope.where(activity_id: params[:activity_id]) if params[:activity_id].present?
        scope = scope.where(coach_id: params[:coach_id]) if params[:coach_id].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.for_date(Date.parse(params[:date])) if params[:date].present?
        scope = scope.order(:starts_at)

        # The calendar asks for a bounded date range and needs every session
        # in it, not a paginated slice — pagination only applies to the
        # unbounded list view.
        if params[:from].present? && params[:to].present?
          scope = scope.where(starts_at: Date.parse(params[:from]).beginning_of_day..Date.parse(params[:to]).end_of_day)
          render json: { sessions: scope.map { |s| SessionSerializer.new(s).as_json } }
        else
          render json: {
            sessions: paginate(scope).map { |s| SessionSerializer.new(s).as_json },
            meta: pagination_meta(scope)
          }
        end
      end

      # GET /api/v1/sessions/:id
      def show
        render json: { session: SessionSerializer.new(@session).as_json }
      end

      # POST /api/v1/sessions
      def create
        activity = Activity.joins(:location)
                            .where(locations: { company_id: current_company.id })
                            .find_by(id: session_params[:activity_id])
        return render json: { error: "Activity not found" }, status: :not_found if activity.nil?

        # An individual session is scheduled *for* one member — the caller
        # picks them here and we book them into the new session in the same
        # request (rolling the session back if the booking can't go through).
        client_id = params.require(:session).permit(:client_id)[:client_id]
        client = client_id.present? ? current_company.clients.find_by(id: client_id) : nil
        return render json: { error: "Client not found" }, status: :not_found if client_id.present? && client.nil?

        attributes = session_params.to_h.merge(
          location_id: activity.location_id,
          capacity: session_params[:capacity].presence || activity.capacity
        )
        # No activity-level price to fall back to — booking is always settled
        # against the member's contract, so a blank price just leaves the
        # session at the column default (0).
        attributes.delete(:price) if attributes[:price].blank?

        result = Sessions::Create.call(attributes: attributes)
        return render(json: { error: result.error }, status: :unprocessable_content) unless result.success?

        if client
          booking = Bookings::Create.call(client: client, session: result.session)
          unless booking.success?
            result.session.destroy
            return render json: { error: booking.error }, status: :unprocessable_content
          end
        end

        render json: { session: SessionSerializer.new(result.session).as_json }, status: :created
      end

      # PATCH /api/v1/sessions/:id
      def update
        result = Sessions::Update.call(session: @session, attributes: session_params.to_h)

        if result.success?
          render json: { session: SessionSerializer.new(result.session).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # POST /api/v1/sessions/:id/cancel
      def cancel
        @session.update!(status: :cancelled)
        AuditLogs::Record.call(
          company: current_company, user: current_user, action: "session.cancelled",
          auditable: @session, metadata: { activity: @session.activity.name, starts_at: @session.starts_at }
        )
        render json: { session: SessionSerializer.new(@session).as_json }
      end

      private

      # Coach-role staff only ever see/touch their own sessions; everyone
      # else with the `sessions` capability sees the whole company.
      def base_scope
        scope = Session.joins(:location).where(locations: { company_id: current_company.id })
        current_staff_member&.coach? ? scope.where(coach_id: current_staff_member.coach_id) : scope
      end

      # Creating/editing/cancelling sessions is an operational (owner/admin/
      # manager) task — coaches can view their schedule but not restructure it.
      def require_session_management!
        return if current_user.owner?
        return if current_staff_member&.active? && current_staff_member.can?(:sessions) && !current_staff_member.coach?

        render_forbidden
      end

      def set_session
        @session = base_scope.find(params[:id])
      end

      def session_params
        params.require(:session).permit(:activity_id, :coach_id, :starts_at, :ends_at, :capacity, :price, :status)
      end
    end
  end
end
