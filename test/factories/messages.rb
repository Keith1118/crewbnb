FactoryBot.define do
  factory :message do
    conversation { nil }
    user { nil }
    body { "MyText" }
    read_at { "2026-03-23 19:46:43" }
  end
end
