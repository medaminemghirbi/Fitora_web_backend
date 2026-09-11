require "rails_helper"

RSpec.describe "Api::V1::AppVersion", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  it "returns null fields when no update has been published yet" do
    get "/api/v1/app_version", headers: auth_headers(owner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["version"]).to be_nil
  end

  it "returns the latest published version to any authenticated role" do
    create(:app_update, version: "1.0.0", published_at: 2.days.ago)
    create(:app_update, version: "2.0.0", published_at: 1.day.ago)

    get "/api/v1/app_version", headers: auth_headers(owner)

    expect(response.parsed_body["version"]).to eq("2.0.0")
  end

  it "works for an admin too" do
    admin = create(:user, :admin)
    create(:app_update, version: "3.0.0")

    get "/api/v1/app_version", headers: auth_headers(admin)

    expect(response.parsed_body["version"]).to eq("3.0.0")
  end
end
