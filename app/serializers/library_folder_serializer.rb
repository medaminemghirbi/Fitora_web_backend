class LibraryFolderSerializer
  def initialize(folder)
    @folder = folder
  end

  def as_json(*)
    return nil if folder.nil?

    {
      id: folder.id,
      name: folder.name,
      document_count: folder.library_documents.count,
      created_at: folder.created_at,
      updated_at: folder.updated_at
    }
  end

  private

  attr_reader :folder
end
