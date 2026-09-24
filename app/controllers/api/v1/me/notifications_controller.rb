module Api
  module V1
    module Me
      # A member's own notifications, on their own app: the same feed as the
      # admin's, read from their Client rather than a User.
      class NotificationsController < Api::V1::NotificationsController
        private

        def require_notification_recipient!
          require_client!
        end

        def recipient
          current_client
        end
      end
    end
  end
end
