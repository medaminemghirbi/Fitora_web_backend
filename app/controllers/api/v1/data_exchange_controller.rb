module Api
  module V1
    # CSV import/export for the four entities an owner most often needs to
    # move in bulk (migrating from another tool, or backing data out).
    # `:entity` in the URL picks the strategy class AND the capability that
    # gates it — deliberately the same capability that gates managing that
    # entity elsewhere (clients/activities/contracts/payments), not a new one.
    class DataExchangeController < BaseController
      before_action :require_company!
      before_action :set_strategy!

      REGISTRY = {
        "clients" => DataExchange::Clients,
        "activities" => DataExchange::Activities,
        "contracts" => DataExchange::Contracts,
        "payments" => DataExchange::Payments
      }.freeze

      # GET /api/v1/data_exchange/:entity/template
      def template
        send_data @strategy.template_csv, filename: "fitora-#{params[:entity]}-modele.csv", type: "text/csv"
      end

      # GET /api/v1/data_exchange/:entity/export
      def export
        send_data @strategy.export_csv(current_company), filename: "fitora-#{params[:entity]}-export.csv", type: "text/csv"
      end

      # POST /api/v1/data_exchange/:entity/import (multipart, field "file")
      def import
        file = params[:file]
        return render json: { error: "No file uploaded" }, status: :unprocessable_content unless file

        result = @strategy.import_csv(company: current_company, user: current_user, io: file)

        if result[:created].positive?
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "data.imported", auditable: current_company,
            metadata: { entity: params[:entity], created: result[:created], error_count: result[:errors].size }
          )
        end

        render json: result
      rescue CSV::MalformedCSVError => e
        render json: { error: "Invalid CSV file: #{e.message}" }, status: :unprocessable_content
      end

      private

      def set_strategy!
        @strategy = REGISTRY[params[:entity]]
        return render json: { error: "Unknown entity: #{params[:entity]}" }, status: :not_found unless @strategy

        require_capability!(params[:entity])
      end
    end
  end
end
