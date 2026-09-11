module Api
  module V1
    module Me
      # Bookable sessions for the client's own company — the "Réserver une
      # séance" screen. Read-only: booking itself is Me::BookingsController#create.
      class SessionsController < BaseController
        before_action :require_client!

        # GET /api/v1/me/sessions?date=YYYY-MM-DD
        def index
          scope = ::Session.joins(:location).where(locations: { company_id: current_client.company_id })
                            .where(status: :scheduled)
                            .upcoming
                            .order(:starts_at)
          scope = scope.for_date(Date.parse(params[:date])) if params[:date].present?

          render json: { sessions: scope.map { |s| SessionSerializer.new(s, current_client: current_client).as_json } }
        end
      end
    end
  end
end
