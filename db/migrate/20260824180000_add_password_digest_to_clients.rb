class AddPasswordDigestToClients < ActiveRecord::Migration[8.0]
  def change
    # Login stays opt-in per client — nil means no mobile login configured
    # yet. A receptionist or the owner sets it from the client's profile
    # (see Client#login_enabled?).
    add_column :clients, :password_digest, :string
  end
end
