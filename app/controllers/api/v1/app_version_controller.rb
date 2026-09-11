module Api
  module V1
    # The running app version, shown in every shell's footer — sourced from
    # the latest AppUpdate an admin published (Api::V1::Admin::AppUpdatesController).
    # Deliberately thin: no media/description here, just enough to render a
    # "vX.Y.Z" badge for any authenticated user.
    class AppVersionController < BaseController
      def show
        latest = AppUpdate.recent.first
        render json: {
          version: latest&.version,
          title: latest&.title,
          published_at: latest&.published_at
        }
      end
    end
  end
end
