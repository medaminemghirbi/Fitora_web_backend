require "rails_helper"

RSpec.describe NotificationChannel, type: :channel do
  let(:company) { create(:company) }

  it "streams for the connected user" do
    stub_connection current_user: company.owner
    subscribe
    expect(subscription).to be_confirmed
    expect(subscription).to have_stream_for(company.owner)
  end
end

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user, :owner) }

  it "accepts a valid JWT in the query string" do
    connect "/cable?token=#{JwtService.encode(user.id)}"
    expect(connection.current_user).to eq(user)
  end

  it "rejects a missing or bad token" do
    expect { connect "/cable" }.to have_rejected_connection
    expect { connect "/cable?token=garbage" }.to have_rejected_connection
  end
end
