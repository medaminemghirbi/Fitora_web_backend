class AbsenceType < ApplicationRecord
  belongs_to :company
  has_many :leave_requests, dependent: :restrict_with_error

  validates :name, presence: true
  validates :abbreviation, presence: true, length: { maximum: 20 },
                           uniqueness: { scope: :company_id, case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  before_validation { self.abbreviation = abbreviation.to_s.strip.upcase.presence }

  # `paid` = draws down the employee's paid-leave (CP) balance.
  DEFAULTS = [
    { name: "Congé payé", abbreviation: "CP", paid: true },
    { name: "Congé sans solde", abbreviation: "CSS", paid: false },
    { name: "Congé maladie", abbreviation: "MAL", paid: false },
    { name: "Congé maternité", abbreviation: "MAT", paid: false },
    { name: "Récupération", abbreviation: "RECUP", paid: false },
    { name: "Congé exceptionnel", abbreviation: "EXCEP", paid: false }
  ].freeze

  def self.seed_defaults_for(company)
    DEFAULTS.each_with_index do |attrs, index|
      type = company.absence_types.find_or_initialize_by(abbreviation: attrs[:abbreviation])
      type.name ||= attrs[:name]
      type.paid = attrs[:paid] if type.new_record?
      type.position = index if type.new_record?
      type.save!
    end
  end
end
