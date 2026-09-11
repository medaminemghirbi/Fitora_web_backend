require "rails_helper"

RSpec.describe "Api::V1::AuditLogs", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "GET /api/v1/audit_logs" do
    it "lists the company's audit logs, most recent first" do
      older = create(:audit_log, company: company, action: "client.created", created_at: 2.days.ago)
      newer = create(:audit_log, company: company, action: "client.updated", created_at: 1.hour.ago)

      get "/api/v1/audit_logs", headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["audit_logs"].map { |l| l["id"] }
      expect(ids).to eq([ newer.id, older.id ])
    end

    it "includes pagination metadata" do
      create_list(:audit_log, 3, company: company)

      get "/api/v1/audit_logs", params: { page: 1, per_page: 2 }, headers: auth_headers(owner)

      meta = response.parsed_body["meta"]
      expect(meta["total"]).to eq(3)
      expect(meta["per_page"]).to eq(2)
      expect(response.parsed_body["audit_logs"].size).to eq(2)
    end

    it "never exposes another company's audit logs" do
      create(:audit_log, company: company)
      other_log = create(:audit_log)

      get "/api/v1/audit_logs", headers: auth_headers(owner)

      ids = response.parsed_body["audit_logs"].map { |l| l["id"] }
      expect(ids).not_to include(other_log.id)
    end

    it "lets a receptionist (reports capability) browse audit logs" do
      receptionist = create(:staff_member, company: company, role: :receptionist)
      create(:audit_log, company: company)

      get "/api/v1/audit_logs", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
    end

    it "forbids a coach (no reports capability) from browsing audit logs" do
      coach_staff = create(:staff_member, company: company, role: :coach)

      get "/api/v1/audit_logs", headers: auth_headers(coach_staff.user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
