module AuditLogs
  class Record
    def self.call(company:, user:, action:, auditable:, metadata: {})
      AuditLog.create!(
        company: company,
        user: user,
        action: action,
        auditable_type: auditable.class.name,
        auditable_id: auditable.id,
        metadata: metadata
      )
    end
  end
end
