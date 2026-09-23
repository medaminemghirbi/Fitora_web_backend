require "rails_helper"

RSpec.describe "Api::V1::ContractTypes", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  let(:plan_params) do
    { contract_type: { name: "Mensuel", billing_period: "monthly", unlimited_bookings: true } }
  end

  describe "GET /api/v1/contract_types" do
    it "lets a receptionist read the catalogue (needed to sign a member up)" do
      create(:contract_type, company: company)
      receptionist = create(:staff_member, company: company, role: :receptionist)

      get "/api/v1/contract_types", headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["plans"].size).to eq(1)
    end
  end

  describe "POST /api/v1/contract_types" do
    it "lets the owner create a plan" do
      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
    end

    it "forbids a receptionist — editing the plan catalogue is configuration" do
      receptionist = create(:staff_member, company: company, role: :receptionist)

      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(receptionist.user)

      expect(response).to have_http_status(:forbidden)
    end

    it "lets a staff member whose role grants :contract_types create a plan" do
      staff = create(:staff_member, company: company, role: :receptionist,
                     assigned_role: create(:role, company: company, permissions: %w[contracts contract_types]))

      post "/api/v1/contract_types", params: plan_params, headers: auth_headers(staff.user)

      expect(response).to have_http_status(:created)
    end
  end

  describe "the pricing grid" do
    let(:boxe) { create(:activity, company: company, name: "Boxe") }
    let(:pilates) { create(:activity, company: company, name: "Pilates") }

    it "stores one price per activity" do
      post "/api/v1/contract_types",
           params: plan_params.merge(activity_prices: [
             { activity_id: boxe.id, price: 50 },
             { activity_id: pilates.id, price: 70 }
           ]),
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      prices = response.parsed_body["plan"]["activity_prices"].to_h { |row| [ row["activity_name"], row["price"].to_f ] }
      expect(prices).to eq("Boxe" => 50.0, "Pilates" => 70.0)
    end

    it "updates a price and drops the activities left out of the grid" do
      plan = create(:contract_type, company: company, activity: boxe, price: 50)
      create(:contract_type_activity, contract_type: plan, activity: pilates, price: 70)

      patch "/api/v1/contract_types/#{plan.id}",
            params: plan_params.merge(activity_prices: [ { activity_id: boxe.id, price: 55 } ]),
            headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      expect(plan.reload.price_for(boxe)).to eq(55)
      expect(plan.price_for(pilates)).to be_nil
    end

    it "ignores an activity belonging to another company" do
      foreign = create(:activity, company: create(:company))

      post "/api/v1/contract_types",
           params: plan_params.merge(activity_prices: [ { activity_id: foreign.id, price: 10 } ]),
           headers: auth_headers(owner)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["plan"]["activity_prices"]).to be_empty
    end
  end
end
