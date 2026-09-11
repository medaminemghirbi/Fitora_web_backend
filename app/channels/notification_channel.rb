# Per-user stream of Notification payloads. Broadcasts come from
# Notification#broadcast (a new notification) and #broadcast_unread_count
# (badge count changes).
class NotificationChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
end
