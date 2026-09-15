# A physical room/hall at the company's location — not a class type
# (Activity) and not the site itself (Location): the actual space clients
# work out in (weight room, yoga studio, pool...). Photo gallery is the
# point — the mobile app shows these so a member knows what the room looks
# like before booking a class held there.
class Salle < ApplicationRecord
  belongs_to :location

  include HasPhotos

  validates :name, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(active: true) }

  delegate :company, to: :location
end
