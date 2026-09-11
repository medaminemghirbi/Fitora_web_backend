class NotificationSerializer
  def initialize(notification)
    @notification = notification
  end

  def as_json(*)
    return nil if notification.nil?

    {
      id: notification.id,
      kind: notification.kind,
      data: notification.data,
      url: notification.url,
      subject: notification.subject_id && { type: notification.subject_type, id: notification.subject_id },
      read: notification.read?,
      created_at: notification.created_at
    }
  end

  private

  attr_reader :notification
end
