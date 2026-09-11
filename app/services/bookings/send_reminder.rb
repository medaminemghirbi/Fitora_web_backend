module Bookings
  # "Remind client" button — sends a booking reminder by SMS via
  # Sms::TunisieSmsClient. Best-effort: any failure (missing phone, missing
  # API credentials, gateway error) is reported back as a Result rather than
  # raised, since this is a one-off action a staff member triggers by hand.
  class SendReminder
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(booking:)
      new(booking: booking).call
    end

    def initialize(booking:)
      @booking = booking
    end

    def call
      mobile = normalize_mobile(booking.client.phone)
      return Result.new(success?: false, error: "Client has no usable phone number") if mobile.blank?

      Sms::TunisieSmsClient.send_message(mobile: mobile, text: message)
      Result.new(success?: true, error: nil)
    rescue Sms::TunisieSmsClient::ConfigurationError, Sms::TunisieSmsClient::RequestError => e
      Result.new(success?: false, error: e.message)
    end

    private

    attr_reader :booking

    def message
      session = booking.session
      company_name = session.location.company.name

      "Bonjour #{booking.client.first_name}, rappel : #{session.activity.name} le " \
        "#{session.starts_at.strftime('%d/%m/%Y à %H:%M')} chez #{company_name}."
    end

    # TunisieSMS expects a bare digits mobile number prefixed with the
    # country code (e.g. "21620111111") — client phones are stored as
    # entered ("+216 20 111 111", "20 111 111"...), so this strips
    # formatting and fills in Tunisia's 216 prefix when it's missing.
    def normalize_mobile(raw)
      digits = raw.to_s.gsub(/\D/, "").delete_prefix("00")
      return nil if digits.blank?
      return digits if digits.start_with?("216")
      return "216#{digits}" if digits.length == 8

      digits
    end
  end
end
