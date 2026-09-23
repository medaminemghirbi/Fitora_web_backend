module AuditLogs
  class Record
    def self.call(company:, user:, action:, auditable:, metadata: {})
      AuditLog.create!(
        company: company,
        user: user,
        action: action,
        auditable_type: auditable.class.name,
        auditable_id: auditable.id,
        metadata: metadata.merge(impersonation_metadata)
      )
    end

    # A Fitora admin impersonating an owner acts AS that owner — that is the
    # point of impersonation, and it means an audit log would otherwise
    # record the owner refunding a payment the admin refunded. Stamp who was
    # really acting, on every entry, without every call site having to
    # remember to.
    def self.impersonation_metadata
      admin = Current.impersonator
      return {} if admin.nil?

      { impersonated_by_id: admin.id, impersonated_by_email: admin.email }
    end
    private_class_method :impersonation_metadata
  end
end
