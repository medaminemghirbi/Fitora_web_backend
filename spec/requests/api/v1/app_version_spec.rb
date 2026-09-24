require "rails_helper"

RSpec.describe "Api::V1::AppVersion", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:company) { create(:company, admin: admin) }

  it "returns null fields when no update has been published yet" do
    get "/api/v1/app_version", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["version"]).to be_nil
  end

  it "returns the latest published version to any authenticated role" do
    create(:app_update, version: "1.0.0", published_at: 2.days.ago)
    create(:app_update, version: "2.0.0", published_at: 1.day.ago)

    get "/api/v1/app_version", headers: auth_headers(admin)

    expect(response.parsed_body["version"]).to eq("2.0.0")
  end

  it "works for a superadmin too" do
    superadmin = create(:user, :superadmin)
    create(:app_update, version: "3.0.0")

    get "/api/v1/app_version", headers: auth_headers(superadmin)

    expect(response.parsed_body["version"]).to eq("3.0.0")
  end
end
