class StaffMemberLocation < ApplicationRecord
  belongs_to :staff_member
  belongs_to :location

  validates :location_id, uniqueness: { scope: :staff_member_id }
end
