require "rails_helper"

RSpec.describe Bookings::SendReminder do
  let(:company) { create(:company, name: "Fitora Test Gym") }
  let(:location) { create(:location, company: company) }
  let(:activity) { create(:activity, location: location, name: "Yoga") }
  let(:session) { create(:session, activity: activity, location: location, starts_at: Time.zone.local(2026, 9, 20, 18, 0)) }

  describe "#call" do
    it "sends an SMS to the client's normalized mobile number" do
      client = create(:client, company: company, first_name: "Ines", phone: "+216 20 111 222")
      booking = create(:booking, client: client, session: session)

      expect(Sms::TunisieSmsClient).to receive(:send_message).with(
        mobile: "21620111222",
        text: a_string_matching(/Ines.*Yoga.*20\/09\/2026.*18:00.*Fitora Test Gym/)
      )

      result = described_class.call(booking: booking)

      expect(result.success?).to be true
    end

    it "fills in the 216 country code for a local 8-digit number" do
      client = create(:client, company: company, phone: "20 111 222")
      booking = create(:booking, client: client, session: session)

      expect(Sms::TunisieSmsClient).to receive(:send_message).with(mobile: "21620111222", text: anything)

      described_class.call(booking: booking)
    end

    it "fails gracefully when the client has no usable phone number" do
      client = create(:client, company: company, phone: "n/a")
      booking = create(:booking, client: client, session: session)

      expect(Sms::TunisieSmsClient).not_to receive(:send_message)

      result = described_class.call(booking: booking)

      expect(result.success?).to be false
      expect(result.error).to be_present
    end

    it "reports a gateway failure instead of raising" do
      client = create(:client, company: company, phone: "+216 20 111 222")
      booking = create(:booking, client: client, session: session)

      allow(Sms::TunisieSmsClient).to receive(:send_message).and_raise(Sms::TunisieSmsClient::ConfigurationError, "TUNISIESMS_API_KEY is not set")

      result = described_class.call(booking: booking)

      expect(result.success?).to be false
      expect(result.error).to eq("TUNISIESMS_API_KEY is not set")
    end
  end
end
