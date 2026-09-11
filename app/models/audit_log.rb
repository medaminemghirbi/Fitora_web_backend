class AuditLog < ApplicationRecord
  belongs_to :company
  belongs_to :user, optional: true

  validates :action, presence: true
  validates :auditable_type, presence: true
  validates :auditable_id, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def auditable
    auditable_type.constantize.find_by(id: auditable_id)
  end
end
