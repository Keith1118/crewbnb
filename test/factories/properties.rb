FactoryBot.define do
  factory :property do
    user { nil }
    title { "MyString" }
    description { "MyText" }
    property_type { "MyString" }
    address { "MyString" }
    city { "MyString" }
    country { "MyString" }
    latitude { 1.5 }
    longitude { 1.5 }
    price_per_night { "9.99" }
    max_guests { 1 }
    bedrooms { 1 }
    bathrooms { 1 }
    wifi_speed { "MyString" }
    has_desk { false }
    has_meeting_room { false }
    has_printer { false }
    has_parking { false }
    status { 1 }
    instant_book { false }
  end
end
