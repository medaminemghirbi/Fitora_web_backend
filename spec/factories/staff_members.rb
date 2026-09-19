FactoryBot.define do
  factory :staff_member do
    user { association :user, :staff }
    company
    active { true }

    transient do
      # Specs say `create(:staff_member, role: :receptionist)` in a hundred
      # places. There is no `role` column any more, so the transient resolves
      # the company's built-in Role with that key — which is what the enum
      # was standing in for all along.
      role { :receptionist }
    end

    assigned_role do
      Role.seed_defaults_for(company) if company.roles.empty?
      company.roles.find_by(key: role.to_s) ||
        raise("No role #{role.inspect} in company #{company.id}")
    end

    # A coach login is one with a Coach of its own — that is now the whole
    # definition of #coach?, so the factory has to supply one.
    coach { role.to_s == "coach" ? association(:coach, company: company) : nil }
  end
end
