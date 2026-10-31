FactoryBot.define do
  factory :api_key do
    firm
    transient do
      token { ApiToken.generate }
    end
    token_digest { ApiToken.digest(token) }
  end
end
