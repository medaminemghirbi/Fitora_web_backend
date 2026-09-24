require "rails_helper"

RSpec.describe "Api::V1::Superadmin::AppUpdates", type: :request do
  let(:superadmin) { create(:user, :superadmin) }
  let(:other_superadmin) { create(:user, :superadmin) }
  let(:admin) { create(:user, :admin) }

  describe "authorization" do
    it "forbids an admin from publishing an update" do
      post "/api/v1/superadmin/app_updates", params: { app_update: { version: "1.2.0", title: "New stuff" } }, headers: auth_headers(admin)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/superadmin/app_updates" do
    it "creates the update and notifies every other superadmin in real time" do
      other_superadmin

      post "/api/v1/superadmin/app_updates",
           params: { app_update: { version: "1.2.0", title: "Nouveau tableau de bord", description: "Refonte du dashboard." } },
           headers: auth_headers(superadmin)

      expect(response).to have_http_status(:created)
      body = response.parsed_body["app_update"]
      expect(body["version"]).to eq("1.2.0")

      notif = other_superadmin.notifications.find_by(kind: "system_update")
      expect(notif).to be_present
      expect(notif.company_id).to be_nil
      expect(notif.data["version"]).to eq("1.2.0")
      expect(notif.url).to eq("/superadmin/updates")
    end

    it "does not notify the superadmin who published it" do
      post "/api/v1/superadmin/app_updates", params: { app_update: { version: "1.2.0", title: "Nouveau tableau de bord" } }, headers: auth_headers(superadmin)

      expect(superadmin.notifications.where(kind: "system_update")).to be_empty
    end

    it "notifies every admin too, on their own read-only page" do
      customer_admin = create(:user, :admin)
      create(:company, admin: customer_admin)

      post "/api/v1/superadmin/app_updates", params: { app_update: { version: "1.2.0", title: "Nouveau tableau de bord" } }, headers: auth_headers(superadmin)

      notif = customer_admin.notifications.find_by(kind: "system_update")
      expect(notif).to be_present
      expect(notif.url).to eq("/admin/updates")
      expect(notif.company_id).to eq(customer_admin.active_company.id)
    end

    it "attaches media" do
      photo = fixture_file_upload("sample.png", "image/png")

      post "/api/v1/superadmin/app_updates",
           params: { app_update: { version: "1.2.0", title: "Nouveau tableau de bord" }, media: [ photo ] },
           headers: auth_headers(superadmin)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["app_update"]["media"].size).to eq(1)
    end

    it "rejects an update with no version" do
      post "/api/v1/superadmin/app_updates", params: { app_update: { title: "Nouveau tableau de bord" } }, headers: auth_headers(superadmin)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/superadmin/app_updates" do
    it "lists updates newest first" do
      create(:app_update, version: "1.0.0", published_at: 2.days.ago)
      create(:app_update, version: "1.1.0", published_at: 1.day.ago)

      get "/api/v1/superadmin/app_updates", headers: auth_headers(superadmin)

      versions = response.parsed_body["app_updates"].map { |u| u["version"] }
      expect(versions).to eq([ "1.1.0", "1.0.0" ])
    end
  end
end
