module DataExchange
  # CSV round-trip for the activity catalogue.
  class Activities
    HEADERS = %w[name session_format duration_minutes capacity emoji description].freeze
    EXAMPLE_ROW = [ "Yoga", "collective", "60", "20", "🧘", "" ].freeze

    def self.template_csv
      CSV.generate do |csv|
        csv << HEADERS
        csv << EXAMPLE_ROW
      end
    end

    def self.export_csv(company)
      CSV.generate do |csv|
        csv << HEADERS
        company.activities.order(:created_at).find_each do |activity|
          csv << [ activity.name, activity.session_format, activity.duration, activity.capacity, activity.emoji, activity.description ]
        end
      end
    end

    def self.import_csv(company:, user:, io:)
      created = 0
      errors = []

      CSV.parse(io.read, headers: true).each_with_index do |row, index|
        activity = company.activities.new(
          name: row["name"].to_s.strip,
          session_format: row["session_format"].to_s.strip,
          duration: row["duration_minutes"],
          capacity: row["capacity"],
          emoji: row["emoji"].to_s.strip.presence,
          description: row["description"].to_s.strip.presence
        )

        if activity.save
          created += 1
        else
          errors << { row: index + 2, message: activity.errors.full_messages.join(", ") }
        end
      end

      { created: created, errors: errors }
    end
  end
end
