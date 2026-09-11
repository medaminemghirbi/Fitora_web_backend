class WorkContractType < ApplicationRecord
  belongs_to :company
  has_many :work_contracts, dependent: :restrict_with_error

  validates :name, presence: true
  validates :abbreviation, presence: true, length: { maximum: 20 },
                           uniqueness: { scope: :company_id, case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  before_validation { self.abbreviation = abbreviation.to_s.strip.upcase.presence }

  # Standard Tunisian employment-contract set — seeded per company on
  # creation (Api::V1::CompaniesController#create) and in db/seeds.rb.
  DEFAULTS = [
    { name: "Contrat à Durée Indéterminée", abbreviation: "CDI", fixed_term: false },
    { name: "Contrat à Durée Déterminée", abbreviation: "CDD", fixed_term: true },
    { name: "Stage d'Initiation à la Vie Professionnelle", abbreviation: "SIVP", fixed_term: true },
    { name: "Contrat Karama", abbreviation: "KARAMA", fixed_term: true },
    { name: "Contrat de Prestation de Service", abbreviation: "FREELANCE", fixed_term: false },
    { name: "Convention de Stage", abbreviation: "STAGE", fixed_term: true }
  ].freeze

  def self.seed_defaults_for(company)
    DEFAULTS.each_with_index do |attrs, index|
      type = company.work_contract_types.find_or_initialize_by(abbreviation: attrs[:abbreviation])
      type.name ||= attrs[:name]
      type.fixed_term = attrs[:fixed_term] if type.new_record?
      type.position = index if type.new_record?
      type.save!
    end
  end
end
