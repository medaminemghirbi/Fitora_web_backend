# Fitora is sold to gyms. A gym's members are records its staff manage — they
# have no account, so every column that only existed to let one sign in and
# be found goes with the surfaces that used them:
#
#   - clients: the password and the two recovery-token pairs, which only ever
#     served the member's own login.
#   - companies.listed_at: the public directory is gone, so a gym is no longer
#     "published" or "unpublished".
#
# Irreversible, like every other pre-launch migration in this repo.
class CloseTheMemberSide < ActiveRecord::Migration[8.1]
  def up
    remove_index :clients, name: :index_clients_on_email_verification_token_digest, if_exists: true
    remove_index :clients, name: :index_clients_on_reset_password_token_digest, if_exists: true

    %i[
      password_digest
      email_verification_token_digest email_verification_sent_at email_verified_at
      reset_password_token_digest reset_password_sent_at
      token_version
    ].each { |column| remove_column :clients, column, if_exists: true }

    remove_index :companies, name: :index_companies_on_listed_at, if_exists: true
    remove_column :companies, :listed_at, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
