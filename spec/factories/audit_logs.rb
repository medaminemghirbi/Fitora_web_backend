FactoryBot.define do
  factory :audit_log do
    company
    user { association :user, :owner }
    action { "client.created" }
    auditable_type { "Client" }
    sequence(:auditable_id) { SecureRandom.uuid }
    metadata { {} }
  end
end
