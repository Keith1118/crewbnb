FactoryBot.define do
  factory :payment do
    booking { nil }
    amount { "9.99" }
    currency { "MyString" }
    stripe_payment_intent_id { "MyString" }
    status { 1 }
  end
end
