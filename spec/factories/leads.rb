FactoryBot.define do
  factory :lead do
    kind { :demo }
    contact_name { "Amine Mghirbi" }
    gym_name { "Power Gym" }
    sequence(:email) { |n| "prospect#{n}@example.com" }
    phone { "+216 20 111222" }
    city { "Tunis" }
    message { "On aimerait voir l'app." }
  end
end
