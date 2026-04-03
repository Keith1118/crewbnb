FactoryBot.define do
  factory :booking do
    property { nil }
    user { nil }
    check_in { "2026-03-23" }
    check_out { "2026-03-23" }
    guests_count { 1 }
    total_price { "9.99" }
    status { 1 }
    special_requests { "MyText" }
    invoice_reference { "MyString" }
  end
end
