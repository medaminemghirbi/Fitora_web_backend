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
      # An owner can run several companies now — current_company resolves
      # through active_company, not "the" company, so specs that just
      # `create(:company, owner: owner)` and expect current_company to be
      # it need this set, same as the real signup flow does.
      company.owner.update!(active_company: company) if company.owner.active_company_id.nil?
    end
  end
end
