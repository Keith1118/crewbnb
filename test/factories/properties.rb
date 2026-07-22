FactoryBot.define do
  factory :property do
    user
    sequence(:title) { |n| "Crew House #{n}" }
    description { "A clean, quiet house set up for working crews." }
    property_type { "house" }
    address { "Main Street" }
    city { "Edenderry" }
    country { "Ireland" }
    # Set explicitly so the after_validation geocode callback stays quiet —
    # it only fires when the address changed and lat/lng didn't.
    latitude  { 53.3428 }
    longitude { -7.0489 }
    price_per_night { "80.0" }
    weekday_discount { 15 }
    max_guests { 4 }
    bedrooms { 2 }
    bathrooms { 1 }
    status { :published }

    trait :draft do
      status { :draft }
    end
  end
end
