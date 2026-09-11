class LibraryDocument < ApplicationRecord
  ALLOWED_FILE_TYPES = %w[application/pdf image/jpeg image/png image/webp].freeze
  MAX_FILE_SIZE = 20.megabytes

  belongs_to :folder, class_name: "LibraryFolder"
  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true

  has_one_attached :file

  validates :title, presence: true
  validate :folder_belongs_to_same_company
  validate :file_is_attached
  validate :file_is_pdf_or_image
  validate :file_is_not_too_large

  scope :active, -> { where(active: true) }
  scope :expiring_soon, -> { where(expires_on: Date.current..30.days.from_now.to_date).order(:expires_on) }

  # Notify the owner right away when an expiry date is set/moved into the
  # warning window, without waiting for the daily scan.
  after_commit :notify_if_expiring, on: [ :create, :update ]

  def expiring_soon?
    expires_on.present? && expires_on.between?(Date.current, 30.days.from_now.to_date)
  end

  def expired?
    expires_on.present? && expires_on < Date.current
  end

  private

  def notify_if_expiring
    return unless active? && expiring_soon?
    return if destroyed?
    return unless saved_change_to_expires_on? || (previously_new_record? && expires_on.present?)

    Notifications::DocumentExpiryChangedJob.perform_later(id)
  end

  def folder_belongs_to_same_company
    return if folder.blank?

    errors.add(:folder, "must belong to the same company") if folder.company_id != company_id
  end

  def file_is_attached
    errors.add(:file, "must be attached") unless file.attached?
  end

  # Relies on Active Storage's default content-type identification (Marcel
  # sniffs the actual bytes, not just the client-declared type) rather than
  # trusting the upload's Content-Type header outright.
  def file_is_pdf_or_image
    return unless file.attached?

    errors.add(:file, "must be a PDF or an image (JPEG, PNG, WebP)") unless file.content_type.in?(ALLOWED_FILE_TYPES)
  end

  def file_is_not_too_large
    return unless file.attached?

    errors.add(:file, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte}MB") if file.blob.byte_size > MAX_FILE_SIZE
  end
end
