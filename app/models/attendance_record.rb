class AttendanceRecord < ApplicationRecord
  belongs_to :booking
  belongs_to :marked_by, class_name: "User", optional: true

  enum :status, { present: 0, absent: 1, late: 2, no_show: 3 }

  validates :booking_id, uniqueness: true
end
