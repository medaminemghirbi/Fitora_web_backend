module Notifications
  # Creates one notification per (company, dedup_key), idempotently. Creating
  # it fires Notification#broadcast (real-time push + badge count). Safe to
  # call from a daily scan and from a synchronous after_commit hook.
  class Push
    def self.call(recipient:, kind:, data:, url:, dedup_key:, subject: nil)
      return nil if recipient.nil?

      # Every company-scoped notification still requires one (a nil company
      # here would silently be a bug in the caller); a platform-level event
      # aimed at a Fitora admin has none by design — see Notification#company.
      company = recipient.company
      return nil if company.nil? && !recipient.admin?

      recipient.notifications.create!(
        company: company,
        kind: kind,
        data: data,
        url: url,
        dedup_key: dedup_key,
        subject: subject
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # Unique index on [company_id, dedup_key] — already notified. Not an error.
      raise unless e.is_a?(ActiveRecord::RecordNotUnique) || e.record&.errors&.of_kind?(:dedup_key, :taken)

      recipient.notifications.find_by(dedup_key: dedup_key)
    end
  end
end
