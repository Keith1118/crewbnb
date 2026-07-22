FactoryBot.define do
  factory :message do
    conversation
    user { conversation.participant_1 }
    body { "Hi — is the house available for a three-week job starting next month?" }
    read_at { nil } # unread by default

    trait :read do
      read_at { Time.current }
    end
  end
end
