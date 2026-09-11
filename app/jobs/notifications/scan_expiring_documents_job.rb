module Notifications
  # Daily: turn library documents approaching their expiry date into owner
  # notifications. Idempotent via the dedup key (record id + expiry date).
  class ScanExpiringDocumentsJob < ApplicationJob
    queue_as :default

    def perform
      Company.includes(:owner).find_each do |company|
        owner = company.owner
        next if owner.nil?

        company.library_documents.active.expiring_soon.includes(:folder).find_each do |document|
          notify(owner, document)
        end
      end
    end

    def notify(owner, document)
      Notifications::Push.call(
        recipient: owner,
        kind: "document_expiring",
        subject: document,
        dedup_key: "doc_exp:#{document.id}:#{document.expires_on}",
        url: "/owner/directories/company-library/#{document.folder_id}",
        data: {
          title: document.title,
          folder_name: document.folder&.name,
          expires_on: document.expires_on&.iso8601
        }
      )
    end
  end
end
