module Api
  module V1
    module Admin
      # The platform changelog an admin edits after each release — version,
      # what's new, screenshots/screen-recordings. Publishing one notifies
      # every other admin AND every owner in real time (NotificationChannel)
      # — the team knows the update went out, and every customer sees what's
      # new (Api::V1::AppUpdatesController is their read-only, non-admin view).
      class AppUpdatesController < BaseController
        before_action :require_admin!

        # GET /api/v1/admin/app_updates
        def index
          updates = AppUpdate.includes(:created_by, media_attachments: :blob).recent
          render json: { app_updates: updates.map { |u| AppUpdateSerializer.new(u).as_json } }
        end

        # POST /api/v1/admin/app_updates (multipart/form-data — media[] are uploads)
        def create
          update = AppUpdate.new(update_params.merge(created_by: current_user))
          update.media.attach(params[:media]) if params[:media].present?

          if update.save
            notify_recipients(update)
            render json: { app_update: AppUpdateSerializer.new(update).as_json }, status: :created
          else
            render json: { error: update.errors.full_messages.first, errors: update.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def update_params
          params.require(:app_update).permit(:version, :title, :description)
        end

        def notify_recipients(update)
          data = { version: update.version, title: update.title, published_by: current_user.full_name }

          User.admin.active.where.not(id: current_user.id).find_each do |admin|
            Notifications::Push.call(
              recipient: admin, kind: "system_update", data: data, url: "/admin/updates",
              dedup_key: "system_update-#{update.id}-#{admin.id}", subject: update
            )
          end

          # Every customer sees the release notes too, on their own read-only
          # page — admins get the editable /admin/updates instead.
          User.owner.active.find_each do |owner|
            Notifications::Push.call(
              recipient: owner, kind: "system_update", data: data, url: "/owner/updates",
              dedup_key: "system_update-#{update.id}-#{owner.id}", subject: update
            )
          end
        end
      end
    end
  end
end
