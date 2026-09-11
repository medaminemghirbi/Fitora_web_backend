class AppUpdateSerializer
  def initialize(update)
    @update = update
  end

  def as_json(*)
    {
      id: update.id,
      version: update.version,
      title: update.title,
      description: update.description,
      published_at: update.published_at,
      created_by: { id: update.created_by.id, full_name: update.created_by.full_name },
      media: media_json
    }
  end

  private

  attr_reader :update

  def media_json
    update.media.map do |file|
      {
        id: file.id,
        filename: file.filename.to_s,
        content_type: file.content_type,
        byte_size: file.byte_size,
        url: Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
      }
    end
  end
end
