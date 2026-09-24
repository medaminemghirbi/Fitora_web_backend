# One CSV upload and how it went. The file is kept on Active Storage while
# DataImportJob works through it; the page polls this record for the result.
class DataImport < ApplicationRecord
  MAX_BYTES = 5.megabytes
  MAX_ROWS = 5_000

  belongs_to :company
  belongs_to :user, optional: true
  has_one_attached :file

  enum :status, { queued: 0, running: 1, done: 2, failed: 3 }

  validates :entity, inclusion: { in: DataExchange::REGISTRY.keys }
  validate :file_is_small_enough, on: :create

  def finished? = done? || failed?

  def strategy = DataExchange::REGISTRY.fetch(entity)

  private

  def file_is_small_enough
    if !file.attached?
      errors.add(:file, "is required")
    elsif file.blob.byte_size > MAX_BYTES
      errors.add(:file, "must be smaller than #{MAX_BYTES / 1.megabyte}MB")
    end
  end
end
