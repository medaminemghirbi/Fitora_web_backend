require "rails_helper"

RSpec.describe RequiredEnv do
  let(:complete) { described_class::REQUIRED.keys.index_with("set") }

  it "passes a complete production environment" do
    expect { described_class.check!(complete) }.not_to raise_error
  end

  it "refuses to boot without outgoing mail, naming what it is for" do
    expect { described_class.check!(complete.except("SMTP_ADDRESS")) }
      .to raise_error(/SMTP_ADDRESS \(outgoing mail/)
  end

  it "treats an empty value as missing" do
    expect(described_class.missing(complete.merge("APP_HOST" => ""))).to have_key("APP_HOST")
  end

  it "only warns about the recommended ones" do
    expect { described_class.check!(complete) }.not_to raise_error
    expect(described_class.missing(complete, described_class::RECOMMENDED).keys).to include("SENTRY_DSN")
  end
end
