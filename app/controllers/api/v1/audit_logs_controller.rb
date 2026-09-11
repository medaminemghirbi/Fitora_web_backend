module Api
  module V1
    class AuditLogsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:reports) }, unless: -> { current_user.owner? }

      # GET /api/v1/audit_logs
      def index
        logs = current_company.audit_logs.includes(:user).recent

        render json: {
          audit_logs: paginate(logs).map { |l| AuditLogSerializer.new(l).as_json },
          meta: pagination_meta(logs)
        }
      end
    end
  end
end
