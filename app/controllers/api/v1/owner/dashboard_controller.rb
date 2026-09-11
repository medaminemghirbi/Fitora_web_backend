module Api
  module V1
    module Owner
      class DashboardController < BaseController
        before_action -> { require_capability!(:reports) }
        before_action :require_company!

        # GET /api/v1/owner/dashboard
        def show
          stats = Dashboard::Statistics.call(company: current_company)

          render json: {
            company: CompanySerializer.new(current_company).as_json,
            stats: stats
          }
        end
      end
    end
  end
end
