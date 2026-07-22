FactoryBot.define do
  factory :contact_submission do
    name { "Aoife Byrne" }
    email { "aoife@contractor.ie" }
    subject { "Availability for a crew of six" }
    message { "Do you have anything near Edenderry for a six-week job?" }
    status { :pending }
  end
end
