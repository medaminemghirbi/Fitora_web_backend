module Clients
  # Adds someone to a gym — and, optionally, sells them a plan and takes the
  # money — in one transaction, which is what actually happens at a front
  # desk. A member who exists but has no subscription because the plan had no
  # price for that activity is exactly the mess this avoids.
  #
  # The email identifies the person across the platform, so an address that
  # already has an account joins that person rather than creating a second
  # one. Their identity is theirs: only what it left blank is filled in. What
  # the gym writes about them (date of birth, address, notes…) goes on this
  # gym's membership, never on the shared person.
  class Enrol
    Result = ServiceResult.define(:client, :contract, :payment, :adopted)

    # Unwinds the transaction when the sale half fails: Contracts::Create
    # reports a refused sale by returning, not by raising, and the member
    # must not survive it.
    Refused = Class.new(StandardError)

    def self.call(**args) = new(**args).call

    def initialize(company:, created_by:, person:, membership:, subscription: nil)
      @company = company
      @created_by = created_by
      @person = person.to_h.stringify_keys
      @membership = membership.to_h.stringify_keys
      @subscription = subscription.presence&.to_h&.symbolize_keys
    end

    def call
      existing = Client.find_by_email(person["email"])
      client = existing || Client.new
      client.assign_attributes(existing ? blanks_only(existing) : person)
      contract = payment = nil

      ActiveRecord::Base.transaction do
        client.save!
        joined = client.join!(company)
        joined.update!(membership) if membership.any?

        if subscription
          sale = sell(client)
          raise Refused, sale.error unless sale.success?

          contract = sale.contract
          payment = sale.payment
        end
      end

      Result.ok(client: client, contract: contract, payment: payment, adopted: existing.present?)
    rescue Refused => e
      Result.failure(e.message)
    rescue ActiveRecord::RecordInvalid => e
      Result.failure(e.record.errors.full_messages.first)
    end

    private

    attr_reader :company, :created_by, :person, :membership, :subscription

    def blanks_only(client)
      person.reject { |key, _| client.public_send(key).present? }
    end

    def sell(client)
      plan = company.contract_types.find_by(id: subscription[:contract_type_id])
      raise Refused, "Plan not found" if plan.nil?

      activity = company.activities.find_by(id: subscription[:activity_id])
      raise Refused, "Activity not found" if activity.nil?

      Contracts::Create.call(
        client: client, contract_type: plan, activity: activity, created_by: created_by,
        starts_on: subscription[:starts_on].presence&.to_date || Date.current,
        discount: subscription[:discount].presence || 0,
        collect_payment: subscription[:collect_payment],
        payment_method: subscription[:payment_method],
        payment_notes: subscription[:payment_notes]
      )
    end
  end
end
