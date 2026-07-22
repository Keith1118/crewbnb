FactoryBot.define do
  factory :booking do
    property
    user
    check_in  { Date.current + 7 }
    check_out { Date.current + 10 }
    guests_count { 2 }
    status { :pending }

    # total_price is calculated by a before_validation callback, so it's
    # deliberately not set here.

    trait :confirmed do
      status { :confirmed }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
