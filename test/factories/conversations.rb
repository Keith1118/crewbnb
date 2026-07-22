FactoryBot.define do
  factory :conversation do
    association :participant_1, factory: :user
    association :participant_2, factory: :user
    property
  end
end
