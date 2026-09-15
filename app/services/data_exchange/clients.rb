module DataExchange
  # CSV round-trip for the client roster — the most common migration path
  # for a gym coming from another system (spreadsheet or a competitor export).
  class Clients
    HEADERS = %w[first_name last_name email phone].freeze
    EXAMPLE_ROW = [ "Amine", "Test", "amine@example.com", "+21620000000" ].freeze

    def self.template_csv
      CSV.generate do |csv|
        csv << HEADERS
        csv << EXAMPLE_ROW
      end
    end

    def self.export_csv(company)
      CSV.generate do |csv|
        csv << HEADERS
        company.clients.order(:created_at).find_each do |client|
          csv << [ client.first_name, client.last_name, client.email, client.phone ]
        end
      end
    end

    def self.import_csv(company:, user:, io:)
      created = 0
      errors = []

      CSV.parse(io.read, headers: true).each_with_index do |row, index|
        client = company.clients.new(
          first_name: row["first_name"].to_s.strip,
          last_name: row["last_name"].to_s.strip,
          email: row["email"].to_s.strip,
          phone: row["phone"].to_s.strip
        )

        if client.save
          created += 1
        else
          errors << { row: index + 2, message: client.errors.full_messages.join(", ") }
        end
      end

      { created: created, errors: errors }
    end
  end
end
