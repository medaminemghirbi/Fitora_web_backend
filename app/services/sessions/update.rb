module Sessions
  class Update
    Result = Struct.new(:success?, :session, :error, keyword_init: true)

    def self.call(session:, attributes:)
      new(session: session, attributes: attributes).call
    end

    def initialize(session:, attributes:)
      @session = session
      @attributes = attributes
    end

    def call
      if session.update(attributes)
        Result.new(success?: true, session: session, error: nil)
      else
        Result.new(success?: false, session: nil, error: session.errors.full_messages.first)
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?(Sessions::Create::COACH_OVERLAP_CONSTRAINT)
        Result.new(success?: false, session: nil, error: "Coach already has a session at that time.")
      else
        raise
      end
    end

    private

    attr_reader :session, :attributes
  end
end
