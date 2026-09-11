module Api
  module V1
    # The owner's read-only view of the platform changelog — same data as
    # Admin::AppUpdatesController, minus the ability to publish. Reached from
    # the "system_update" notification's deep link (/owner/updates).
    class AppUpdatesController < BaseController
      before_action :require_owner!

      # GET /api/v1/app_updates
      def index
        updates = AppUpdate.includes(:created_by, media_attachments: :blob).recent
        render json: { app_updates: updates.map { |u| AppUpdateSerializer.new(u).as_json } }
      end
    end
  end
end
