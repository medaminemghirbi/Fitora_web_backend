FactoryBot.define do
  factory :support_ticket do
    association :company
    association :created_by, factory: [ :user, :admin ]
    sequence(:subject) { |n| "Problème #{n}" }
    message { "Ça ne fonctionne pas comme prévu." }
    status { :open }
  end
end
