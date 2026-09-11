module Api
  module V1
    module Owner
      class ReportsController < BaseController
        before_action :require_owner!
        before_action :require_company!

        # GET /api/v1/owner/reports/export?period_type=month&period=2026-02
        # GET /api/v1/owner/reports/export?period_type=year&period=2026
        def export
          period = Reports::Period.parse(period_type: params[:period_type], period: params[:period])
          package = Reports::CompanyWorkbook.call(company: current_company, period: period)

          send_data package.to_stream.read,
                     filename: "fitora-rapport-#{period.slug}.xlsx",
                     type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                     disposition: "attachment"
        rescue Reports::Period::InvalidPeriod => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end
    end
  end
end
