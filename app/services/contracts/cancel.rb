module Contracts
  class Cancel
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(contract:)
      new(contract: contract).call
    end

    def initialize(contract:)
      @contract = contract
    end

    def call
      return Result.new(success?: false, error: "This contract is already cancelled.") if contract.cancelled?

      contract.current_period.update!(status: :cancelled)
      Result.new(success?: true, error: nil)
    end

    private

    attr_reader :contract
  end
end
