FactoryBot.define do
  factory :notification do
    company
    recipient { company.admin }
    kind { "contract_expiring" }
    url { "/admin/notifications" }
    sequence(:dedup_key) { |n| "test:#{n}" }
    data { { "title" => "Sample" } }
  end
end
