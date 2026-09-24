# Per-recipient stream of Notification payloads — an admin's or superadmin's, or a
# member's on their own app. Broadcasts come from Notification#broadcast (a
# new notification) and #broadcast_unread_count (badge count changes).
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user || current_client
  end

  def unsubscribed
    stop_all_streams
  end
end
