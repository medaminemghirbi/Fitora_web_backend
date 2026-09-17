require "rails_helper"

RSpec.describe "Api::V1::Leads", type: :request do
  let(:params) do
    { lead: { kind: "demo", contact_name: "Amine Mghirbi", gym_name: "Power Gym",
              email: "Amine@Example.COM", phone: "+216 20 111222", city: "Tunis", message: "On veut voir l'app." } }
  end

  describe "POST /api/v1/leads" do
    it "takes a demo request from someone with no account at all" do
      post "/api/v1/leads", params: params

      expect(response).to have_http_status(:created)
      lead = Lead.last
      expect(lead).to be_demo
      expect(lead).to be_new_request
      expect(lead.email).to eq("amine@example.com")
    end

    it "takes a quote request the same way" do
      post "/api/v1/leads", params: { lead: params[:lead].merge(kind: "quote") }

      expect(Lead.last).to be_quote
    end

    it "requires a contact, a gym and a usable email" do
      post "/api/v1/leads", params: { lead: { contact_name: "", gym_name: "", email: "pas-un-email" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Lead.count).to eq(0)
    end

    it "never lets a prospect set the status or the internal notes" do
      post "/api/v1/leads", params: { lead: params[:lead].merge(status: "converted", internal_notes: "à ignorer") }

      lead = Lead.last
      expect(lead).to be_new_request
      expect(lead.internal_notes).to be_nil
    end

    it "is write-only from outside: there is no way to read requests back" do
      create(:lead)

      get "/api/v1/leads"

      expect(response).to have_http_status(:not_found)
    end
  end
end
