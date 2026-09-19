require "rails_helper"

# A gym adding members off a phone number could not save the second one: the
# form sends email: "", the model kept it, and the unique index on
# lower(email) exempts NULL but not "".
RSpec.describe "Api::V1::Clients without an email", type: :request do
  let(:owner) { create(:user, :owner) }
  let!(:company) { create(:company, owner: owner) }

  def add!(first_name, email:)
    post "/api/v1/clients",
         params: { client: { first_name: first_name, last_name: "Sansmail", phone: "20#{rand(100000..999999)}", email: email } },
         headers: auth_headers(owner)
  end

  it "saves a member with no email at all" do
    add!("Amira", email: "")

    expect(response).to have_http_status(:created)
    expect(Client.find_by(first_name: "Amira").email).to be_nil
  end

  it "saves a second one — the empty string is not an address anyone owns" do
    add!("Amira", email: "")
    add!("Bilel", email: "")

    expect(response).to have_http_status(:created)
    expect(company.reload.clients.count).to eq(2)
  end

  it "treats whitespace as no email rather than as an address" do
    add!("Sonia", email: "   ")

    expect(response).to have_http_status(:created)
    expect(Client.find_by(first_name: "Sonia").email).to be_nil
  end

  it "still joins two people who really do share an address" do
    add!("Amira", email: "shared@example.tn")
    add!("Amira", email: "SHARED@example.tn")

    # One person, one account — the email is the identity across gyms.
    expect(Client.where(email: "shared@example.tn").count).to eq(1)
  end

  it "still refuses to make a login without an address to send it to" do
    member = create(:client, company: company, email: nil)

    expect(member.update(password: "password123")).to be(false)
  end
end
