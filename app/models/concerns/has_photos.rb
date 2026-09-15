# A gallery of optional photos (as opposed to HasPhoto's single thumbnail)
# — content-type is Marcel-sniffed the same way, never the client-declared
# header. Used by Salle, whose whole point is showing what the room looks
# like before a member picks a class in it.
module HasPhotos
  extend ActiveSupport::Concern

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 10.megabytes
  MAX_IMAGES = 10

  included do
    has_many_attached :images

    validate :images_are_not_too_many
    validate :images_are_all_photos
    validate :images_are_not_too_large
  end

  private

  def images_are_not_too_many
    return unless images.attached?

    errors.add(:images, "cannot include more than #{MAX_IMAGES} photos") if images.count > MAX_IMAGES
  end

  def images_are_all_photos
    return unless images.attached?

    images.each do |file|
      next if file.content_type.in?(ALLOWED_IMAGE_TYPES)

      errors.add(:images, "must all be images (JPEG, PNG, WebP)")
      break
    end
  end

  def images_are_not_too_large
    return unless images.attached?

    images.each do |file|
      next if file.blob.byte_size <= MAX_IMAGE_SIZE

      errors.add(:images, "must each be smaller than #{MAX_IMAGE_SIZE / 1.megabyte}MB")
      break
    end
  end
end
