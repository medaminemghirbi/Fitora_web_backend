module Sessions
  class Create
    Result = ServiceResult.define(:session)

    COACH_OVERLAP_CONSTRAINT = "no_overlapping_coach_sessions".freeze

    def self.call(attributes:)
      new(attributes: attributes).call
    end

    def initialize(attributes:)
      @attributes = attributes
    end

    def call
      # A session runs at the gym that owns its activity — there is no other
      # place it could be, so callers no longer have to say it.
      session = Session.new(attributes.reverse_merge(company_id: activity_company_id))

      if session.save
        Result.new(success?: true, session: session, error: nil)
      else
        Result.new(success?: false, session: nil, error: session.errors.full_messages.first)
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?(COACH_OVERLAP_CONSTRAINT)
        Result.new(success?: false, session: nil, error: "Coach already has a session at that time.")
      else
        raise
      end
    end

    private

    def activity_company_id
      Activity.where(id: attributes[:activity_id]).pick(:company_id)
    end

    attr_reader :attributes
  end
end
