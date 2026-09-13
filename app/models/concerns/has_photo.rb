# A single optional photo shown as a thumbnail/card image. Same
# has_one_attached shape as Company#logo (Marcel-sniffed content type, not
# the client-declared one).
module HasPhoto
  extend ActiveSupport::Concern

  ALLOWED_PHOTO_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_PHOTO_SIZE = 10.megabytes

  included do
    has_one_attached :photo

    validate :photo_is_an_image
    validate :photo_is_not_too_large
  end

  private

  def photo_is_an_image
    return unless photo.attached?

    errors.add(:photo, "must be an image (JPEG, PNG, WebP)") unless photo.content_type.in?(ALLOWED_PHOTO_TYPES)
  end

  def photo_is_not_too_large
    return unless photo.attached?

    errors.add(:photo, "must be smaller than #{MAX_PHOTO_SIZE / 1.megabyte}MB") if photo.blob.byte_size > MAX_PHOTO_SIZE
  end
end
