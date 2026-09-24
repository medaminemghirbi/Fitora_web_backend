# The one shape every service answers with: `success?`, `error`, and the
# fields that use case produces.
#
#   Result = ServiceResult.define(:booking, :waitlisted)
#   Result.ok(booking: booking, waitlisted: false)
#   Result.failure("This session is full.")
#
# Each service still names its own fields, so callers keep reading
# `result.booking`; what they no longer have to remember is how success and
# failure are spelled in this particular one.
module ServiceResult
  def self.define(*fields)
    Struct.new(:success?, :error, *fields, keyword_init: true) do
      def self.ok(**values) = new(success?: true, error: nil, **values)
      def self.failure(error, **values) = new(success?: false, error: error, **values)
    end
  end
end
