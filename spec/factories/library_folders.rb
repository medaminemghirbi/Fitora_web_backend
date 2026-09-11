FactoryBot.define do
  factory :library_folder do
    company
    sequence(:name) { |n| "Folder #{n}" }
  end
end
