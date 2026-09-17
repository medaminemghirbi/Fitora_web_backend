module DataExchange
  # CSV import for contracts — deliberately thin: it just resolves the
  # client (by email) and membership plan (by name) already in the company,
  # then hands off to Contracts::Create so pricing/periods/payment status
  # stay computed the exact same way a manual "new contract" does.
  class Contracts
    HEADERS = %w[client_email contract_type_name activity_name starts_at].freeze
    EXAMPLE_ROW = [ "amine@example.com", "Abonnement mensuel", "Yoga", Date.current.to_s ].freeze

    def self.template_csv
      CSV.generate do |csv|
        csv << HEADERS
        csv << EXAMPLE_ROW
      end
    end

    def self.export_csv(company)
      CSV.generate do |csv|
        csv << HEADERS
        company.contracts.includes(:client, :contract_type, :activity).order(:created_at).find_each do |contract|
          csv << [ contract.client.email, contract.contract_type.name, contract.activity.name, contract.starts_at&.to_date ]
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

        type_name = row["contract_type_name"].to_s.strip
        contract_type = company.contract_types.find_by(name: type_name)
        unless contract_type
          errors << { row: line, message: "No membership plan named \"#{type_name}\"" }
          next
        end

        activity_name = row["activity_name"].to_s.strip
        activity = Activity.where(company_id: company.id).find_by(name: activity_name)
        unless activity
          errors << { row: line, message: "No activity named \"#{activity_name}\"" }
          next
        end

        starts_on = parse_date(row["starts_at"])
        if starts_on == :invalid
          errors << { row: line, message: "Invalid date: #{row['starts_at']}" }
          next
        end

        result = ::Contracts::Create.call(client: client, contract_type: contract_type, activity: activity, created_by: user, starts_on: starts_on || Date.current)
        if result.success?
          created += 1
        else
          errors << { row: line, message: result.error }
        end
      end

      { created: created, errors: errors }
    end

    def self.parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError, TypeError
      :invalid
    end
    private_class_method :parse_date
  end
end
