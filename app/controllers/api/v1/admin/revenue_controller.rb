module Api
  module V1
    module Admin
      class RevenueController < BaseController
        before_action -> { require_capability!(:revenue) }
        before_action :require_company!

        # GET /api/v1/admin/revenue
        def show
          render json: Dashboard::Revenue.call(company: current_company)
        end
      end
    end
  end
end
