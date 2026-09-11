FactoryBot.define do
  factory :company do
    association :owner, factory: [ :user, :owner ]
    sequence(:name) { |n| "Studio #{n}" }
    timezone { "Africa/Tunis" }
    currency { "TND" }

    # Every company has exactly one location in production (auto-created
    # at signup) — mirrored here so specs don't need to remember to create one
    # before exercising anything that reads company.location.
    after(:create) do |company|
      create(:location, company: company) unless company.locations.exists?
      Role.seed_defaults_for(company) if company.roles.empty?
    end
  end
end
