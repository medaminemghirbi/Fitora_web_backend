module Api
  module V1
    module Owner
      class RevenueController < BaseController
        before_action -> { require_capability!(:reports) }
        before_action :require_company!

        # GET /api/v1/owner/revenue
        def show
          render json: Dashboard::Revenue.call(company: current_company)
        end
      end
    end
  end
end
