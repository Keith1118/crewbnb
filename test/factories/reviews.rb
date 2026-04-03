FactoryBot.define do
  factory :review do
    booking { nil }
    rating { 1 }
    comment { "MyText" }
    reviewable_type { "MyString" }
    reviewable_id { 1 }
  end
end
