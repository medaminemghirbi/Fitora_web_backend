module Notifications
  # Fired synchronously (well, enqueued) from LibraryDocument#after_commit when
  # an expiry date lands in the warning window — so the owner is told without
  # waiting for the next daily scan.
  class DocumentExpiryChangedJob < ApplicationJob
    queue_as :default
    discard_on ActiveJob::DeserializationError

    def perform(document_id)
      document = LibraryDocument.active.includes(:folder, company: :owner).find_by(id: document_id)
      return if document.nil? || !document.expiring_soon?

      ScanExpiringDocumentsJob.new.notify(document.company.owner, document)
    end
  end
end
