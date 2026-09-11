class SupplierSerializer
  def initialize(supplier)
    @supplier = supplier
  end

  def as_json(*)
    {
      id: supplier.id,
      name: supplier.name,
      category: supplier.category,
      contact_name: supplier.contact_name,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      notes: supplier.notes,
      active: supplier.active,
      photo_url: photo_url,
      created_at: supplier.created_at
    }
  end

  private

  attr_reader :supplier

  def photo_url
    return nil unless supplier.photo.attached?

    Rails.application.routes.url_helpers.rails_blob_path(supplier.photo, only_path: true)
  end
end
