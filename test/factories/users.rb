FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123!" }
    first_name { "Test" }
    last_name  { "User" }
    role { :guest }

    # Guests can only book once their business is verified.
    trait :business_verified do
      business_verified_at { Time.current }
      company_name { "Test Contracting Ltd" }
      vat_number { "IE1234567X" }
    end

    trait :host do
      role { :host }
    end

    trait :admin do
      role { :admin }
    end
  end
end
