FactoryBot.define do
  factory :availability do
    property { nil }
    date { "2026-03-23" }
    available { false }
    custom_price { "9.99" }
  end
end
