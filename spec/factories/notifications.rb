FactoryBot.define do
  factory :notification do
    company
    recipient { company.owner }
    kind { "contract_expiring" }
    url { "/owner/notifications" }
    sequence(:dedup_key) { |n| "test:#{n}" }
    data { { "title" => "Sample" } }
  end
end
