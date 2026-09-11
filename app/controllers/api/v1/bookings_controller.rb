module Api
  module V1
    class BookingsController < BaseController
      before_action :require_company!
      before_action :set_booking, only: [ :show, :cancel, :remind ]

      # GET /api/v1/bookings — filterable list of the company's bookings (coaches
      # narrowed to their own sessions)
      def index
        scope = org_scope.order(created_at: :desc)

        if params[:q].present?
          t = "%#{params[:q].strip}%"
          scope = scope.joins(:client).joins(session: :activity)
            .where("clients.first_name ILIKE :t OR clients.last_name ILIKE :t OR activities.name ILIKE :t", t: t)
        end

        if params[:format] == "csv"
          send_data bookings_csv(scope), filename: "bookings-#{Date.current}.csv"
        else
          render json: {
            bookings: paginate(scope).map { |b| BookingSerializer.new(b).as_json },
            meta: pagination_meta(scope)
          }
        end
      end

      # GET /api/v1/bookings/:id
      def show
        return render_forbidden unless BookingPolicy.new(current_user, @booking).show?

        render json: { booking: BookingSerializer.new(@booking).as_json }
      end

      # POST /api/v1/bookings — staff books a client into a session
      def create
        return render_forbidden unless BookingPolicy.new(current_user, nil).create?

        client = current_company.clients.find_by(id: params[:client_id])
        return render json: { error: "Client not found" }, status: :not_found if client.nil?

        session = Session.joins(:location).where(locations: { company_id: current_company.id }).find_by(id: params[:session_id])
        return render json: { error: "Session not found" }, status: :not_found if session.nil?

        result = Bookings::Create.call(client: client, session: session)

        if result.success?
          render json: { booking: BookingSerializer.new(result.booking).as_json }, status: :created
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # POST /api/v1/bookings/:id/cancel
      def cancel
        return render_forbidden unless BookingPolicy.new(current_user, @booking).cancel?

        result = Bookings::Cancel.call(booking: @booking)

        if result.success?
          AuditLogs::Record.call(
            company: @booking.session.location.company, user: current_user, action: "booking.cancelled",
            auditable: @booking, metadata: { client: @booking.client.full_name, activity: @booking.session.activity.name }
          )
          render json: { booking: BookingSerializer.new(@booking.reload).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # POST /api/v1/bookings/:id/remind — "Remind client" button, sends an
      # SMS via Sms::TunisieSmsClient (Bookings::SendReminder).
      def remind
        return render_forbidden unless BookingPolicy.new(current_user, @booking).remind?

        result = Bookings::SendReminder.call(booking: @booking)

        if result.success?
          AuditLogs::Record.call(
            company: @booking.session.location.company, user: current_user, action: "booking.reminder_sent",
            auditable: @booking, metadata: { client: @booking.client.full_name }
          )
          render json: { status: "sent" }
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      private

      # Company only — never narrowed to "this coach's own sessions" the way
      # org_scope is. set_booking uses this, not org_scope: a coach hitting
      # another coach's booking is a BookingPolicy#show? 403 (a role check),
      # not a 404 — only a booking truly outside the company should 404.
      def company_scope
        Booking.joins(session: :location).where(locations: { company_id: current_company.id })
      end

      def org_scope
        current_staff_member&.coach? ? company_scope.where(sessions: { coach_id: current_staff_member.coach_id }) : company_scope
      end

      def bookings_csv(scope)
        CSV.generate do |csv|
          csv << [ "Client", "Activity", "Session start", "Status", "Amount", "Payment status" ]
          scope.includes(:client, session: :activity).find_each do |b|
            csv << [ b.client.full_name, b.session.activity.name, b.session.starts_at, b.status, b.amount, b.payment_status ]
          end
        end
      end

      def set_booking
        @booking = company_scope.find(params[:id])
      end
    end
  end
end
