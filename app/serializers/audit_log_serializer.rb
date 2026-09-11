class AuditLogSerializer
  def initialize(audit_log)
    @audit_log = audit_log
  end

  def as_json(*)
    {
      id: audit_log.id,
      action: audit_log.action,
      auditable_type: audit_log.auditable_type,
      auditable_id: audit_log.auditable_id,
      metadata: audit_log.metadata,
      created_at: audit_log.created_at,
      user: audit_log.user && { id: audit_log.user.id, full_name: audit_log.user.full_name }
    }
  end

  private

  attr_reader :audit_log
end
