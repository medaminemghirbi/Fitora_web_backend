module Sessions
  class Create
    Result = Struct.new(:success?, :session, :error, keyword_init: true)

    COACH_OVERLAP_CONSTRAINT = "no_overlapping_coach_sessions".freeze

    def self.call(attributes:)
      new(attributes: attributes).call
    end

    def initialize(attributes:)
      @attributes = attributes
    end

    def call
      session = Session.new(attributes)

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

    attr_reader :attributes
  end
end
