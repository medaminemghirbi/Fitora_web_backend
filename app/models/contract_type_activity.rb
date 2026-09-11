class ContractTypeActivity < ApplicationRecord
  belongs_to :contract_type
  belongs_to :activity

  validates :activity_id, uniqueness: { scope: :contract_type_id }
end
