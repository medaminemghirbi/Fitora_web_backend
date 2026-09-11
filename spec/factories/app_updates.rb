FactoryBot.define do
  factory :app_update do
    association :created_by, factory: [ :user, :admin ]
    sequence(:version) { |n| "1.#{n}.0" }
    title { "Nouveautés du mois" }
    description { "Quelques améliorations et corrections." }
  end
end
