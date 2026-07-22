FactoryBot.define do
  factory :availability do
    property
    date { Date.current + 5 }
    available { false } # a blocked night
    custom_price { nil }

    trait :custom_priced do
      available { true }
      custom_price { "120.0" }
    end
  end
end
