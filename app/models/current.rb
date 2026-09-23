# Per-request state that a service has no other honest way to reach.
#
# Deliberately tiny, and deliberately not a back door for passing the current
# user around: a service that needs to know who is acting should be told, as
# an argument. The one thing here is the exception, because it is invisible
# by design.
#
# When a Fitora admin impersonates an owner
# (Api::V1::Admin::CompaniesController#impersonate), current_user IS the
# owner for the whole session — that is the point, so the admin sees exactly
# what the owner sees. The consequence is that every audit log written during
# that session would otherwise name the owner for something the admin did.
# AuditLogs::Record reads this to say who was really at the keyboard.
class Current < ActiveSupport::CurrentAttributes
  attribute :impersonator
end
