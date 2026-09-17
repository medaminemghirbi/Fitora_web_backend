require "rails_helper"

RSpec.describe "Api::V1::Auth client self-registration", type: :request do
  let(:params) do
    { first_name: "Rania", last_name: "Ferjani", email: "rania@example.com", phone: "+216 20 111222", password: "password123" }
  end

  it "creates an account with no gym attached — gyms come later, from the directory" do
    post "/api/v1/auth/register_client", params: params

    expect(response).to have_http_status(:created)
    expect(response.parsed_body["account_type"]).to eq("client")
    expect(response.parsed_body["token"]).to be_present

    client = Client.find_by_email("rania@example.com")
    expect(client.companies).to be_empty
    expect(client.login_enabled?).to be true
  end

  it "sends the verification email" do
    expect { post "/api/v1/auth/register_client", params: params }
      .to have_enqueued_mail(AccountMailer, :email_verification)
  end

  it "claims the account a gym already recorded for that email, keeping its history" do
    gym = create(:company)
    walk_in = create(:client, company: gym, email: "rania@example.com", first_name: "R.")

    post "/api/v1/auth/register_client", params: params

    expect(response).to have_http_status(:created)
    expect(Client.where("lower(email) = ?", "rania@example.com").count).to eq(1)
    expect(walk_in.reload.login_enabled?).to be true
    # The gym they were already recorded at is still theirs.
    expect(walk_in.companies).to include(gym)
  end

  it "refuses to overwrite an account that already has a login" do
    create(:client, email: "rania@example.com", password: "password123")

    post "/api/v1/auth/register_client", params: params

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to match(/already exists/i)
  end

  it "rejects a password shorter than the minimum" do
    post "/api/v1/auth/register_client", params: params.merge(password: "short")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "signs in afterwards through the same login endpoint as everyone else" do
    post "/api/v1/auth/register_client", params: params
    post "/api/v1/auth/login", params: { email: "rania@example.com", password: "password123" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["account_type"]).to eq("client")
  end
end
