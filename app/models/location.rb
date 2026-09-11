class Location < ApplicationRecord
  belongs_to :company

  has_many :activities, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :coach_locations, dependent: :destroy
  has_many :coaches, through: :coach_locations
  has_many :contract_type_locations, dependent: :destroy
  has_many :contract_types, through: :contract_type_locations
  has_many :staff_member_locations, dependent: :destroy
  has_many :staff_members, through: :staff_member_locations

  validates :name, presence: true
  validates :timezone, presence: true

  scope :active, -> { where(active: true) }
end
