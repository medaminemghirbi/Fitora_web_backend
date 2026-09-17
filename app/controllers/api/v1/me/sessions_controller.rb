module Api
  module V1
    module Me
      # Bookable sessions across the gyms the client belongs to — the
      # "Réserver une séance" screen. Read-only: booking itself is
      # Me::BookingsController#create.
      class SessionsController < BaseController
        before_action :require_client!
        before_action :require_member_company!

        # GET /api/v1/me/sessions?date=YYYY-MM-DD&company_id=
        def index
          company_ids = member_company ? [ member_company.id ] : current_client.companies.ids
          # The scoping IS the tenancy check here: company_ids comes from the
          # client's own memberships, so a gym they have not joined cannot appear.
          scope = ::Session.where(company_id: company_ids) # rubocop:disable Fitora/UnscopedTenantQuery
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
