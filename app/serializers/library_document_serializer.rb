class LibraryDocumentSerializer
  def initialize(document)
    @document = document
  end

  def as_json(*)
    return nil if document.nil?

    {
      id: document.id,
      folder_id: document.folder_id,
      title: document.title,
      reference_number: document.reference_number,
      issued_on: document.issued_on,
      expires_on: document.expires_on,
      expired: document.expired?,
      notes: document.notes,
      active: document.active,
      file: file_json,
      created_by: document.created_by && { id: document.created_by.id, full_name: document.created_by.full_name },
      created_at: document.created_at,
      updated_at: document.updated_at
    }
  end

  private

  attr_reader :document

  def file_json
    return nil unless document.file.attached?

    {
      filename: document.file.filename.to_s,
      content_type: document.file.content_type,
      byte_size: document.file.byte_size,
      url: Rails.application.routes.url_helpers.file_api_v1_library_document_path(document)
    }
  end
end
