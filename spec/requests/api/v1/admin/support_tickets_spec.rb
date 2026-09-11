require "rails_helper"

RSpec.describe "Api::V1::Admin::SupportTickets", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  describe "authorization" do
    it "forbids an owner from listing the admin support inbox" do
      get "/api/v1/admin/support_tickets", headers: auth_headers(owner)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/admin/support_tickets" do
    it "lists tickets across every company" do
      other_company = create(:company)
      t1 = create(:support_ticket, company: company, created_by: owner)
      t2 = create(:support_ticket, company: other_company, created_by: other_company.owner)

      get "/api/v1/admin/support_tickets", headers: auth_headers(admin)

      ids = response.parsed_body["support_tickets"].map { |t| t["id"] }
      expect(ids).to include(t1.id, t2.id)
      expect(response.parsed_body["support_tickets"].first["company"]).to be_present
    end

    it "filters by status" do
      open_ticket = create(:support_ticket, company: company, created_by: owner, status: :open)
      create(:support_ticket, company: company, created_by: owner, status: :resolved)

      get "/api/v1/admin/support_tickets", params: { status: "open" }, headers: auth_headers(admin)

      ids = response.parsed_body["support_tickets"].map { |t| t["id"] }
      expect(ids).to eq([ open_ticket.id ])
    end
  end

  describe "PATCH /api/v1/admin/support_tickets/:id/resolve" do
    it "marks the ticket resolved" do
      ticket = create(:support_ticket, company: company, created_by: owner)

      patch "/api/v1/admin/support_tickets/#{ticket.id}/resolve", headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      expect(ticket.reload).to be_resolved
    end
  end
end
