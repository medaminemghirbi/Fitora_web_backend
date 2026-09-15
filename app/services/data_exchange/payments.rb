module DataExchange
  # CSV import for payments. A Payment can never stand alone (see
  # Payment#linked_to_exactly_one_payable) — an imported row is recorded
  # against the client's current contract period, the same target the
  # "Encaisser" action on a contract would use.
  class Payments
    HEADERS = %w[client_email amount payment_method paid_at].freeze
    EXAMPLE_ROW = [ "amine@example.com", "90", "cash", Date.current.to_s ].freeze

    def self.template_csv
      CSV.generate do |csv|
        csv << HEADERS
        csv << EXAMPLE_ROW
      end
    end

    def self.export_csv(company)
      CSV.generate do |csv|
        csv << HEADERS
        company.payments.includes(:client).order(:created_at).find_each do |payment|
          csv << [ payment.client.email, payment.amount, payment.payment_method, payment.paid_at&.to_date ]
        end
      end
    end

    def self.import_csv(company:, user:, io:)
      created = 0
      errors = []

      CSV.parse(io.read, headers: true).each_with_index do |row, index|
        line = index + 2
        email = row["client_email"].to_s.strip.downcase
        client = company.clients.find_by(email: email)
        unless client
          errors << { row: line, message: "No client found with email #{email}" }
          next
        end

        period = client.current_contract&.current_period
        unless period
          errors << { row: line, message: "#{email} has no active contract to record a payment against" }
          next
        end

        method = row["payment_method"].to_s.strip.presence || "cash"
        unless ::Payment::SELECTABLE_METHODS.include?(method)
          errors << { row: line, message: "Invalid payment method: #{method} (use cash, bank_transfer or other)" }
          next
        end

        result = ::Payments::Record.call(
          client: client, company: company, created_by: user,
          amount: row["amount"], payment_method: method, contract_period: period
        )
        if result.success?
          created += 1
        else
          errors << { row: line, message: result.error }
        end
      end

      { created: created, errors: errors }
    end
  end
end
