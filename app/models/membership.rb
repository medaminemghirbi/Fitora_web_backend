# A person's link to one gym. The person (Client) is global — one row per
# human, identified by their email — and belongs to as many gyms as they like;
# everything the gym owns about them (when they joined, whether they are still
# active there, the gym's private notes) lives here, not on the person.
class Membership < ApplicationRecord
  belongs_to :client
  belongs_to :company

  before_validation { self.joined_at ||= Time.current }

  validates :client_id, uniqueness: { scope: :company_id }

  scope :active, -> { where(active: true) }
end
