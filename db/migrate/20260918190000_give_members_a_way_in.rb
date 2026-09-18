# A gym's members get the mobile app back: they see their gym's schedule,
# book a slot, cancel it, and read their own subscription and attendance.
#
# This is not the member marketplace that was removed — there is no gym
# directory, no self-signup and no way to reach a gym you are not already a
# member of. The gym enables the account from the member's own file, which is
# why the login columns come back and `mobile_auth_key` does not: a pairing
# key exists to attach a device that has no account, and these have one.
#
# Irreversible, like every other pre-launch migration in this repo. Any
# password that existed before 20260918170000 dropped these columns is gone;
# staff re-enable the handful that were in use.
class GiveMembersAWayIn < ActiveRecord::Migration[8.1]
  def up
    add_column :clients, :password_digest, :string, if_not_exists: true

    add_column :clients, :email_verification_token_digest, :string, if_not_exists: true
    add_column :clients, :email_verification_sent_at, :datetime, if_not_exists: true
    add_column :clients, :email_verified_at, :datetime, if_not_exists: true

    add_column :clients, :reset_password_token_digest, :string, if_not_exists: true
    add_column :clients, :reset_password_sent_at, :datetime, if_not_exists: true

    add_index :clients, :email_verification_token_digest, unique: true, if_not_exists: true
    add_index :clients, :reset_password_token_digest, unique: true, if_not_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
