# One cell of a plan's pricing grid: what this activity costs under this
# plan's billing period. A row existing is also what makes the activity
# sellable under that plan — see ContractType#grants_access_to?.
class ContractTypeActivity < ApplicationRecord
  belongs_to :contract_type
  belongs_to :activity

  validates :activity_id, uniqueness: { scope: :contract_type_id }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
end
