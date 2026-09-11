class AddAccountRecoveryToUsersAndClients < ActiveRecord::Migration[8.0]
  def change
    # Shared by both User (owner/staff — never admin, gated at the
    # controller level, see PasswordResetsController) and Client. Tokens
    # are stored as a digest, never in the clear — the raw value only ever
    # exists in the emailed link (see PasswordResettable/EmailVerifiable).
    %i[users clients].each do |table|
      add_column table, :reset_password_token_digest, :string
      add_column table, :reset_password_sent_at, :datetime
      add_column table, :email_verification_token_digest, :string
      add_column table, :email_verification_sent_at, :datetime
      add_column table, :email_verified_at, :datetime

      add_index table, :reset_password_token_digest, unique: true
      add_index table, :email_verification_token_digest, unique: true
    end
  end
end
