# Closes a security-audit finding: a password reset didn't invalidate any
# JWT issued before it — the stolen-token-then-reset scenario left the
# stolen token fully working for up to JwtService::EXPIRATION (7 days)
# regardless. Every token now embeds the token_version it was issued
# under; bumping this column (see app/models/concerns/has_token_version.rb)
# makes every previously-issued token fail on its next request.
class AddTokenVersionToUsersAndClients < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :token_version, :integer, null: false, default: 0
    add_column :clients, :token_version, :integer, null: false, default: 0
  end
end
