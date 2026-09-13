require "rails_helper"

RSpec.describe "filter_parameters" do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "redacts PII and financial fields that don't match a generic pattern" do
    sensitive = {
      bank_iban: "TN59 1000 6035 0000 0012 3456",
      bank_name: "BIAT",
      cnss_number: "12345678",
      date_of_birth: "1990-01-01",
      phone: "+216 20 000 000",
      address: "12 Rue de la Liberté",
      emergency_contact_name: "Ahmed",
      emergency_contact_phone: "+216 21 111 111",
      notes: "Allergic to peanuts",
      reason: "Family emergency",
      termination_reason: "Performance"
    }

    filtered = filter.filter(sensitive)

    sensitive.each_key { |key| expect(filtered[key]).to eq("[FILTERED]") }
  end

  it "still redacts the pre-existing generic patterns (password, email, token, etc.)" do
    filtered = filter.filter(password: "x", email: "a@b.com", auth_token: "x", api_key: "x", ssn: "x")

    expect(filtered.values).to all(eq("[FILTERED]"))
  end

  it "leaves ordinary, non-sensitive fields untouched" do
    filtered = filter.filter(first_name: "Ahmed", status: "active")

    expect(filtered).to eq(first_name: "Ahmed", status: "active")
  end
end
