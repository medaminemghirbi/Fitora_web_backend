class LibraryFolder < ApplicationRecord
  belongs_to :company
  belongs_to :created_by, class_name: "User", optional: true

  has_many :library_documents, foreign_key: :folder_id, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :company_id }
end
