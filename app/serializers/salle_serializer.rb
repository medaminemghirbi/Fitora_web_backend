class SalleSerializer
  def initialize(salle)
    @salle = salle
  end

  def as_json(*)
    {
      id: salle.id,
      location_id: salle.location_id,
      name: salle.name,
      description: salle.description,
      capacity: salle.capacity,
      active: salle.active,
      image_urls: image_urls
    }
  end

  private

  attr_reader :salle

  def image_urls
    salle.images.map { |image| Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true) }
  end
end
