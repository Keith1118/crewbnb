FactoryBot.define do
  factory :review do
    booking
    reviewer { booking.user }
    reviewable { booking.property }
    rating { 5 }
    comment { "Spotless, quiet, and perfect for the crew. Would book again." }
  end
end
