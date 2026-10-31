FactoryBot.define do
  factory :firm do
    sequence(:name) { |n| "Firm #{n}" }
    uuid { SecureRandom.uuid }
    balance_cents { 0 }
  end
end
