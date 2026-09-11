class ContractTypeLocation < ApplicationRecord
  belongs_to :contract_type
  belongs_to :location

  validates :location_id, uniqueness: { scope: :contract_type_id }
end
