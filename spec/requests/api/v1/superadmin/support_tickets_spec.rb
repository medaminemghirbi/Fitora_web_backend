require "rails_helper"

RSpec.describe "Api::V1::Superadmin::SupportTickets", type: :request do
  let(:superadmin) { create(:user, :superadmin) }
  let(:admin) { create(:user, :admin) }
  let!(:company) { create(:company, admin: admin) }

  describe "authorization" do
    it "forbids an admin from listing the superadmin support inbox" do
      get "/api/v1/superadmin/support_tickets", headers: auth_headers(admin)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/superadmin/support_tickets" do
    it "lists tickets across every company" do
      other_company = create(:company)
      t1 = create(:support_ticket, company: company, created_by: admin)
      t2 = create(:support_ticket, company: other_company, created_by: other_company.admin)

      get "/api/v1/superadmin/support_tickets", headers: auth_headers(superadmin)

      ids = response.parsed_body["support_tickets"].map { |t| t["id"] }
      expect(ids).to include(t1.id, t2.id)
      expect(response.parsed_body["support_tickets"].first["company"]).to be_present
    end

    it "filters by status" do
      open_ticket = create(:support_ticket, company: company, created_by: admin, status: :open)
      create(:support_ticket, company: company, created_by: admin, status: :resolved)

      get "/api/v1/superadmin/support_tickets", params: { status: "open" }, headers: auth_headers(superadmin)

      ids = response.parsed_body["support_tickets"].map { |t| t["id"] }
      expect(ids).to eq([ open_ticket.id ])
    end
  end

  describe "PATCH /api/v1/superadmin/support_tickets/:id/resolve" do
    it "marks the ticket resolved" do
      ticket = create(:support_ticket, company: company, created_by: admin)

      patch "/api/v1/superadmin/support_tickets/#{ticket.id}/resolve", headers: auth_headers(superadmin)

      expect(response).to have_http_status(:ok)
      expect(ticket.reload).to be_resolved
    end
  end
end
