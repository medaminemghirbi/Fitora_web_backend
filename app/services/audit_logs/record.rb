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

    # A Gymly superadmin impersonating an admin acts AS that admin — that is the
    # point of impersonation, and it means an audit log would otherwise
    # record the admin refunding a payment the superadmin refunded. Stamp who was
    # really acting, on every entry, without every call site having to
    # remember to.
    def self.impersonation_metadata
      superadmin = Current.impersonator
      return {} if superadmin.nil?

      { impersonated_by_id: superadmin.id, impersonated_by_email: superadmin.email }
    end
    private_class_method :impersonation_metadata
  end
end
