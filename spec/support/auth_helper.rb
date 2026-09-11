module AuthHelper
  def auth_headers(account)
    token = account.is_a?(Client) ? JwtService.encode(client_id: account.id) : JwtService.encode(account.id)
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelper, type: :request
end
