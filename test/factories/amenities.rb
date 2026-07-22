FactoryBot.define do
  factory :amenity do
    sequence(:name) { |n| "Amenity #{n}" }
    icon { "wifi" }
    category { :work }
  end
end
