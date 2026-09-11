FactoryBot.define do
  factory :library_document do
    association :folder, factory: :library_folder
    company { folder.company }
    sequence(:title) { |n| "Document #{n}" }
    active { true }

    after(:build) do |document|
      document.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
    end
  end
end
